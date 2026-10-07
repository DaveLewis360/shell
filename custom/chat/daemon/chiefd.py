#!/usr/bin/env python3
"""chiefd — bridges the chat sidebar to an opencode server (v2 API).

Sidebar transport: unix socket at $XDG_STATE_HOME/chief/agent.sock carrying
newline-delimited JSON (consumer: AgentClient.qml).
opencode transport: the HTTP/SSE API of `opencode serve` (v2 /api/* routes).
The daemon spawns its own server with the user's HOME as the working
directory and authenticates with the per-run password printed on stdout.

Stdlib only. State under $XDG_STATE_HOME/chief/.
"""

from __future__ import annotations

import asyncio
import base64
import json
import os
import re
import signal
import subprocess
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

HOME = Path.home()
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "chief"
SOCK_PATH = STATE_DIR / "agent.sock"
SESSION_FILE = STATE_DIR / "session.json"
MODEL_FILE = STATE_DIR / "model.json"

OC_HOST = "127.0.0.1"
OC_PORT = int(os.environ.get("CHIEFD_OC_PORT", "4109"))
AGENT_NAME = os.environ.get("CHIEFD_AGENT", "chief")
HISTORY_LIMIT = 40
PERMISSION_POLL = 1.5
PERMISSION_TITLES = {
    "shell": "Run command",
    "edit": "Edit files",
    "read": "Read file",
    "webfetch": "Fetch URL",
    "external_directory": "Access outside the workspace",
}


def pick_port() -> int:
    """Find a free port near OC_PORT; the daemon never adopts a foreign server."""
    import socket as pysock

    for port in range(OC_PORT, OC_PORT + 20):
        with pysock.socket(pysock.AF_INET, pysock.SOCK_STREAM) as s:
            try:
                s.bind((OC_HOST, port))
                return port
            except OSError:
                continue
    raise RuntimeError("no free port for the opencode server")


def log(*args) -> None:
    print("[chiefd]", *args, flush=True)


class OcClient:
    """Blocking HTTP helper for the opencode v2 API (call via to_thread)."""

    def __init__(self, base: str, password: str | None, port: int | None = None) -> None:
        self.base = base
        self.password = password
        self.port = port

    def request(self, method: str, path: str, body: dict | None = None, timeout: float = 30):
        req = urllib.request.Request(self.base + path, method=method)
        if self.password:
            token = base64.b64encode(f"opencode:{self.password}".encode()).decode()
            req.add_header("Authorization", "Basic " + token)
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            req.add_header("Content-Type", "application/json")
        try:
            with urllib.request.urlopen(req, data=data, timeout=timeout) as resp:
                raw = resp.read()
                code = resp.status
        except urllib.error.HTTPError as e:
            return e.code, e.read()
        try:
            return code, json.loads(raw)
        except Exception:
            return code, raw

    def sse_get(self, path: str):
        """Yield parsed `data:` payloads from an SSE endpoint. Blocking."""
        req = urllib.request.Request(self.base + path)
        if self.password:
            token = base64.b64encode(f"opencode:{self.password}".encode()).decode()
            req.add_header("Authorization", "Basic " + token)
        with urllib.request.urlopen(req, timeout=None) as resp:
            for raw_line in resp:
                line = raw_line.decode(errors="replace").rstrip("\n")
                if line.startswith("data:"):
                    payload = line[5:].strip()
                    if not payload:
                        continue
                    try:
                        yield json.loads(payload)
                    except json.JSONDecodeError:
                        continue


class Chief:
    def __init__(self) -> None:
        self.oc: OcClient | None = None
        self.server_proc: subprocess.Popen | None = None
        self.loop: asyncio.AbstractEventLoop | None = None
        self.session_id: str | None = None
        self.model: dict | None = None            # {"providerID", "id"} as Model.Ref
        self.providers: list = []
        self.busy = False
        self.turn_ended: asyncio.Event | None = None   # set when the live turn finishes
        self.turn_text = ""                       # accumulated assistant text of the live turn
        self.clients: set[asyncio.StreamWriter] = set()
        self.queue: asyncio.Queue = asyncio.Queue()
        self.known_permissions: set[str] = set()
        self.pending_permissions: dict[str, dict] = {}   # asked, not yet answered

    # ---------- opencode server lifecycle ----------

    def ensure_server(self) -> None:
        # Always spawn a dedicated server: adopting a running one would mean
        # guessing its password; writes then fail with auth errors.
        if self.server_proc is not None and self.server_proc.poll() is None:
            return  # already running
        if self.server_proc is not None:
            try:
                self.server_proc.kill()
            except Exception:
                pass
        # A fresh server prints a fresh password; never reuse the old one.
        self.oc.password = None
        log(f"starting opencode serve on port {self.oc.port}")
        # Gate tool use on THIS server instance only (the user's other
        # opencode instances are unaffected). Read-only tools stay allowed;
        # shell commands and file edits require the user's approval in the
        # sidebar. Agent .md frontmatter permissions are NOT honoured by
        # this opencode build, hence the injected config layer.
        server_env = dict(os.environ)
        server_env["OPENCODE_CONFIG_CONTENT"] = json.dumps({
            "permission": {
                "edit": "ask",
                "bash": "ask",
                "webfetch": "allow",
            }
        })
        proc = subprocess.Popen(
            ["opencode", "serve", f"--hostname={OC_HOST}", f"--port={self.oc.port}"],
            cwd=str(HOME),
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=server_env,
        )

        self.server_proc = proc

        def watch_stdout() -> None:
            assert proc.stdout
            for line in proc.stdout:
                line = line.rstrip()
                if line:
                    log("[serve]", line)
                if self.oc.password is None:
                    m = re.search(r"server password (\S+)", line)
                    if m:
                        self.oc.password = m.group(1)
                        log("server password acquired")

        threading.Thread(target=watch_stdout, daemon=True).start()

        deadline = time.time() + 60
        while time.time() < deadline:
            if proc.poll() is not None:
                raise RuntimeError("opencode serve exited during startup")
            if self.oc.password:
                code, _ = self._try(1, "GET", "/api/session", timeout=2)
                if code == 200:
                    log("opencode server is up")
                    return
            time.sleep(0.5)
        raise RuntimeError("opencode server did not come up in 60s")

    def _try(self, attempts: int, method: str, path: str, timeout: float, body: dict | None = None):
        result = (0, b"")
        for _ in range(attempts):
            try:
                return self.oc.request(method, path, body=body, timeout=timeout)
            except Exception as e:  # server briefly down / connection reset
                result = (-1, str(e).encode())
                time.sleep(0.4)
        return result

    # ---------- session / state ----------

    def load_state(self) -> None:
        try:
            self.model = json.loads(MODEL_FILE.read_text())
        except Exception:
            self.model = None

        session_id = None
        try:
            session_id = json.loads(SESSION_FILE.read_text()).get("sessionID")
        except Exception:
            pass

        if session_id:
            code, _ = self._try(3, "GET", f"/api/session/{session_id}", timeout=8)
            if code == 200:
                self.session_id = session_id
                log("reusing session", session_id)
                return
            log("stored session gone, creating a new one")

        self.create_session()

    def create_session(self) -> None:
        code, body = self._try(10, "POST", "/api/session", timeout=15, body={})
        if code != 200:
            raise RuntimeError(f"cannot create session: {code} {body}")
        self.session_id = body["data"]["id"]
        SESSION_FILE.write_text(json.dumps({"sessionID": self.session_id}))
        # run every turn as the chief agent
        self._try(3, "POST", f"/api/session/{self.session_id}/agent", timeout=10, body={"agent": AGENT_NAME})
        if self.model:
            self._try(3, "POST", f"/api/session/{self.session_id}/model", timeout=10, body={"model": self.model})
        log("created session", self.session_id)

    def save_model(self) -> None:
        MODEL_FILE.write_text(json.dumps(self.model or {}))

    # ---------- sidebar transport ----------

    async def broadcast(self, payload: dict) -> None:
        line = json.dumps(payload) + "\n"
        dead = []
        for writer in list(self.clients):
            try:
                writer.write(line.encode())
                await writer.drain()
            except Exception:
                dead.append(writer)
        for writer in dead:
            self.clients.discard(writer)

    def push_event(self, payload: dict) -> None:
        # Called from the SSE thread; asyncio.Queue is not thread-safe, so hop
        # through the main loop instead of relying on a polling waker.
        if self.loop is not None:
            self.loop.call_soon_threadsafe(self.queue.put_nowait, payload)

    async def broadcast_error(self, message: str, auth: bool = False) -> None:
        # Surface which model failed: provider 401s are cryptic ("Missing
        # Authentication header" = no API key stored for that provider).
        model = ""
        if self.model:
            model = f" [{self.model.get('providerID', '?')}/{self.model.get('id', '?')}]"
        hint = " - no API key for this provider? run: opencode auth login" if auth else ""
        await self.broadcast({"type": "error", "message": f"{message}{model}{hint}"})

    async def send_status(self) -> None:
        await self.broadcast({
            "type": "status",
            "state": "online",
            "model": self.model,
        })

    async def send_models(self) -> None:
        await self.broadcast({"type": "models", "providers": self.providers})

    async def send_history(self) -> None:
        messages: list[dict] = []
        if self.session_id:
            code, body = await asyncio.to_thread(
                self._try, 3, "GET", f"/api/session/{self.session_id}/message", 15
            )
            if code == 200:
                entries = body.get("data", body) if isinstance(body, dict) else body
                # the API lists messages newest-first; the sidebar wants them
                # chronological. User messages carry `text` top-level, assistant
                # messages carry text parts in `content`.
                for entry in list(reversed(entries or []))[-HISTORY_LIMIT:]:
                    etype = entry.get("type")
                    if etype == "user":
                        text = str(entry.get("text", "")).strip()
                    elif etype == "assistant":
                        text = "".join(
                            c.get("text", "") for c in entry.get("content", []) if c.get("type") == "text"
                        ).strip()
                    else:
                        continue
                    if text:
                        messages.append({"sender": etype, "text": text})
        await self.broadcast({"type": "history", "messages": messages})

    # ---------- turn handling ----------

    async def handle_send(self, text: str) -> None:
        if not self.session_id:
            await self.broadcast({"type": "error", "message": "no active session"})
            return
        if self.busy:
            await self.broadcast({"type": "error", "message": "the chief is still working - abort first"})
            return

        self.busy = True
        self.turn_text = ""
        self.turn_ended = asyncio.Event()
        try:
            code, resp = await asyncio.to_thread(
                self._try, 3, "POST", f"/api/session/{self.session_id}/prompt", 20, {"text": text}
            )
            if code != 200:
                await self.broadcast({"type": "error", "message": f"prompt failed ({code}): {str(resp)[:200]}"})
                return

            # prompt returns immediately (async delivery). The turn's end is
            # signalled by SSE session.execution.* (deltas precede it in the
            # event queue, so the UI sees all text first). The wait endpoint is
            # only a backstop for a dead SSE stream - and it must be looped,
            # because it returns instantly when the session is still idle
            # (the turn has not started yet).
            backstop = asyncio.create_task(self._wait_backstop())
            try:
                await asyncio.wait_for(self.turn_ended.wait(), timeout=900)
            except asyncio.TimeoutError:
                await self.broadcast({"type": "error", "message": "turn timed out"})
            finally:
                backstop.cancel()
        finally:
            self.busy = False
            self.turn_ended = None
            await self.broadcast({"type": "messageDone"})

    async def _wait_backstop(self) -> None:
        """Fallback turn-end detector for when the SSE stream is down."""
        ended = self.turn_ended
        if ended is None:
            return
        for _ in range(6):
            if ended.is_set():
                return
            t0 = time.monotonic()
            await asyncio.to_thread(
                self._try, 1, "POST", f"/api/experimental/session/{self.session_id}/wait", 900
            )
            if ended.is_set():
                return
            if time.monotonic() - t0 > 2.0:
                # the call genuinely blocked, so the turn ran all the way to idle
                await asyncio.sleep(0.3)  # let queued deltas flush first
                ended.set()
                return
            await asyncio.sleep(0.75)  # session was still idle; wait for the turn to start
        ended.set()  # turn never started; stop waiting

    async def handle_event(self, event: dict) -> None:
        etype = event.get("type", "")
        data = event.get("data", {}) or {}

        if etype == "session.text.delta":
            if data.get("sessionID") != self.session_id:
                return
            self.turn_text += data.get("delta", "")
            await self.broadcast({"type": "assistantText", "text": self.turn_text})
            return

        if etype == "session.execution.failed":
            if data.get("sessionID") == self.session_id:
                # v2 embeds the failure here (e.g. provider.no-route "Model
                # unavailable: zai-coding-plan/glm-4.6"), not as provider.auth.
                err = data.get("error")
                msg = (err.get("message") if isinstance(err, dict) else None) or (
                    json.dumps(err)[:200] if err else ""
                )
                if msg:
                    await self.broadcast_error(msg, auth=(err or {}).get("type") == "provider.auth")
                if self.turn_ended is not None:
                    self.turn_ended.set()
            return

        if etype == "session.execution.succeeded":
            if data.get("sessionID") == self.session_id and self.turn_ended is not None:
                self.turn_ended.set()
            return

        if etype in ("provider.auth", "session.error"):
            message = ""
            if isinstance(data, dict):
                inner = data.get("error", data)
                message = json.dumps(inner)[:300] if not isinstance(inner, str) else inner
            await self.broadcast_error(message or etype, auth=etype == "provider.auth")
            return

        # permission events (names vary across versions); the poller in the
        # busy-wait loop is the reliable path, events only accelerate the UI
        if "permission" in etype and ("ask" in etype or "updated" in etype):
            await self.poll_permissions()
            return

    async def poll_permissions(self) -> None:
        """Diff the server's pending permission list and surface new asks."""
        if not self.session_id:
            return
        code, body = await asyncio.to_thread(
            self._try, 1, "GET", f"/api/session/{self.session_id}/permission", 8
        )
        if code != 200:
            return
        requests = body.get("data", body) if isinstance(body, dict) else body
        for req in requests or []:
            rid = str(req.get("id") or req.get("requestID", ""))
            if not rid or rid in self.known_permissions:
                continue
            self.known_permissions.add(rid)
            # v2 API: {action, resources: [...], save: [...]} e.g.
            # shell + ["uname -a"] + save ["uname *"]
            action = str(req.get("action", "") or "")
            resources = [str(r) for r in (req.get("resources") or []) if r]
            if resources:
                detail = "\n".join(resources[:5])
            else:
                detail = str(req.get("metadata") or "")[:300]
            title = req.get("title") or PERMISSION_TITLES.get(action, f"Permission requested ({action or 'unknown'})")
            frame = {
                "type": "permission",
                "id": rid,
                "title": title,
                "detail": detail,
            }
            self.pending_permissions[rid] = frame
            await self.broadcast(frame)

    async def handle_permission_reply(self, rid: str, decision: str) -> None:
        if not self.session_id:
            return
        code, resp = await asyncio.to_thread(
            self._try, 3, "POST", f"/api/session/{self.session_id}/permission/{rid}/reply", 15,
            {"decision": decision},
        )
        log("permission reply", rid, decision, "->", code, str(resp)[:120])
        if 200 <= code < 300:
            self.pending_permissions.pop(rid, None)

    async def refresh_models(self) -> None:
        """The model catalog loads lazily on fresh servers; retry until non-empty."""
        for _ in range(120):
            code, body = await asyncio.to_thread(self._try, 1, "GET", "/api/model", 15)
            if code == 200:
                models = body.get("data", []) if isinstance(body, dict) else []
                if models:
                    grouped: dict[str, dict] = {}
                    for m in models:
                        pid = m.get("providerID", "")
                        g = grouped.setdefault(pid, {"providerID": pid, "name": m.get("providerID", pid), "models": []})
                        g["models"].append({
                            "modelID": m.get("modelID", m.get("id", "")),
                            "name": m.get("name") or m.get("modelID") or m.get("id", ""),
                            "free": "free" in str(m.get("modelID", "")),
                        })
                    self.providers = list(grouped.values())
                    log("model catalog:", len(models), "models")
                    # Sidebar clients that connected before the catalog was
                    # ready already got an empty models frame - push the real one.
                    await self.send_models()
                    break
            await asyncio.sleep(2)

    async def sse_reader(self) -> None:
        """Blocking SSE consumer running in a thread; reconnects forever."""
        while True:
            try:
                for event in self.oc.sse_get("/api/event"):
                    self.push_event(event)
            except Exception as e:
                log("event stream dropped:", e)
            await asyncio.sleep(2)
            # A dropped stream is usually transient - only respawn the server
            # when the process itself is gone, never while it still owns the port.
            if self.server_proc is None or self.server_proc.poll() is not None:
                try:
                    await asyncio.to_thread(self.ensure_server)
                except Exception as e:
                    log("opencode server still down:", e)

    async def permission_poller(self) -> None:
        """Surface permission asks while a turn is running."""
        while True:
            await asyncio.sleep(PERMISSION_POLL)
            if self.busy:
                try:
                    await self.poll_permissions()
                except Exception as e:
                    log("permission poll error:", e)


CHIEF: Chief | None = None


async def client_connected(reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
    chief: Chief = CHIEF
    log("sidebar connected")
    chief.clients.add(writer)
    try:
        await chief.send_status()
        await chief.send_models()
        await chief.send_history()
        # re-surface permissions asked while no sidebar was attached, so the
        # card is not lost across panel open/close cycles (the turn stays
        # blocked server-side until answered)
        for frame in list(chief.pending_permissions.values()):
            await chief.broadcast(frame)
        while True:
            line = await reader.readline()
            if not line:
                break
            try:
                msg = json.loads(line)
            except json.JSONDecodeError:
                continue

            mtype = msg.get("type")
            if mtype == "send":
                asyncio.create_task(chief.handle_send(str(msg.get("text", ""))))
            elif mtype == "permission":
                asyncio.create_task(
                    chief.handle_permission_reply(str(msg.get("id", "")), str(msg.get("response", "reject")))
                )
            elif mtype == "abort":
                if chief.session_id:
                    asyncio.create_task(
                        asyncio.to_thread(chief._try, 3, "POST", f"/api/session/{chief.session_id}/interrupt", 10)
                    )
            elif mtype == "newSession":
                chief.busy = False
                await asyncio.to_thread(chief.create_session)
                await chief.broadcast({"type": "history", "messages": []})
                await chief.send_status()
            elif mtype == "setModel":
                chief.model = {"providerID": str(msg.get("providerID", "")), "id": str(msg.get("modelID", ""))}
                chief.save_model()
                if chief.session_id:
                    asyncio.create_task(asyncio.to_thread(
                        chief._try, 3, "POST", f"/api/session/{chief.session_id}/model", 10,
                        {"model": chief.model},
                    ))
                await chief.send_status()
    except (ConnectionResetError, asyncio.IncompleteReadError):
        pass
    finally:
        chief.clients.discard(writer)
        writer.close()
        log("sidebar disconnected")


async def main() -> None:
    global CHIEF

    STATE_DIR.mkdir(parents=True, exist_ok=True)
    if SOCK_PATH.exists():
        SOCK_PATH.unlink()

    chief = Chief()
    port = pick_port()
    chief.oc = OcClient(f"http://{OC_HOST}:{port}", None, port=port)
    chief.ensure_server()
    chief.load_state()
    CHIEF = chief

    loop = asyncio.get_running_loop()

    async def pump() -> None:
        while True:
            event = await chief.queue.get()
            try:
                await chief.handle_event(event)
            except Exception as e:
                log("event handling error:", e)

    # The SSE reader blocks on urlopen; run it on its own thread with its own
    # loop and hop events into the main loop via the queue.
    threading.Thread(
        target=lambda: asyncio.run(chief.sse_reader()),
        daemon=True,
    ).start()

    chief.loop = loop

    asyncio.create_task(pump())
    asyncio.create_task(chief.permission_poller())
    asyncio.create_task(chief.refresh_models())

    server = await asyncio.start_unix_server(client_connected, path=str(SOCK_PATH))
    os.chmod(SOCK_PATH, 0o600)
    log("listening on", SOCK_PATH)
    log("agent:", AGENT_NAME, "| model:", chief.model)

    stop = asyncio.Event()
    loop.add_signal_handler(signal.SIGINT, stop.set)
    loop.add_signal_handler(signal.SIGTERM, stop.set)
    await stop.wait()
    server.close()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
