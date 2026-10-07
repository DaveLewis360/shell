#!/usr/bin/env python3
"""Tiny test client for chiefd: connects to the agent socket, sends a message
and prints every frame the daemon produces. Stdlib only.

Usage:
  test_client.py "list my home directory"
  test_client.py --model zai-coding-plan glm-4.6 "say hi"
  test_client.py --perm <id> once     # answer a pending permission request
"""

import json
import os
import socket
import sys
import threading
from pathlib import Path

SOCK = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "chief/agent.sock"


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(str(SOCK))

    stop = threading.Event()

    def reader() -> None:
        buf = b""
        while not stop.is_set():
            chunk = sock.recv(4096)
            if not chunk:
                print("[disconnected]", flush=True)
                stop.set()
                return
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                print("<", line.decode(), flush=True)

    threading.Thread(target=reader, daemon=True).start()

    if args[0] == "--perm":
        sock.send((json.dumps({"type": "permission", "id": args[1], "response": args[2]}) + "\n").encode())
    elif args[0] == "--model":
        sock.send((json.dumps({"type": "setModel", "providerID": args[1], "modelID": args[2]}) + "\n").encode())
        args = args[3:]
        if args:
            sock.send((json.dumps({"type": "send", "text": " ".join(args)}) + "\n").encode())
    else:
        sock.send((json.dumps({"type": "send", "text": " ".join(args)}) + "\n").encode())

    try:
        while not stop.is_set():
            stop.wait(0.2)
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
