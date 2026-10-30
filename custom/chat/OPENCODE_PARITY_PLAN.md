# opencode-paritás: funkciólista + implementációs terv (sidebar)

Forrás: opencode TUI docs (slash parancsok, keybind-ek), illetve a **telepített szerver élő
OpenAPI specje** (`GET /openapi.json`, opencode v2.0.24, port 4110) — a lenti végpontok mind
ellenőrizve a tényleges specen, nem a wiki alapján.

Jelenlegi állapot: `chiefd.py` + `AgentClient.qml` + `Content.qml` + `ChatMessage.qml`
lefedi a send/stream/permission/model-picker/agent-picker/interrupt/mágnes-alapokat.
A terv ezekre épül, nem írja felül őket.

---

## 0. A user háztartási kérése (elsőbbség)

### A. „A sidebar agent mindig tudja, mi a feladata" (persona/context)

**Mi a helyzet most:** az agent személyisége az `agent/*.md` rendszerpromptban van; a chiefd
session létrehozáskor és újrahasználatkor `POST /session/{id}/agent`-dal kiküldi. Ez működik,
de kétféleképpen lyukadhat ki:

1. A sidebar-ból **semmi nem látszik** abból, hogy kit beszélgetünk (a picker leíráson kívül).
2. A **session-höz kötött kontextus** (pl. „szűk sidebarban, markdown-ban, röviden válaszolj")
   csak az agent .md-ben van; ha session új, vagy másik agent váltás, az UI-korlátok nem
   biztos, hogy átjönnek.

**Terv:**

| # | Mit | Hogyan |
|---|-----|--------|
| A1 | Az aktív agent teljes profilja látszon | `GET /api/agent/{id}` → `{name, description, system}`. chiefd az `agentInfo` frame-ben küldi (`status` mellé); az agent pill hosszú-nyomás/kattintás → info sheet a leírással + a rendszerprompt első soraival. |
| A2 | Session szintű, agent-független kontextus | `PUT /api/experimental/session/{id}/instructions/entries/{key}` — chiefd session létrehozáskor/újrahasználatkor beír egy `sidebar` kulcsot: „A válaszok egy quickshell sidebar szűk paneljén jelennek meg markdown-ként: rövid válasz, bullet list, code block parancsokhoz." Így **minden turn-ban** ott van, bármelyik agent is fut. |
| A3 | Biztosíték elfelejtett ellenőrzésre | `handle_send` előtt a chiefd API-ból visszaolvassa a session `agent` mezőjét; ha nem egyezik `self.agent`-dal, újra `POST /agent` (szinkron, a prompt előtt). |
| A4 | Váltás láthatóvá tétele | `setAgent` + `session.agent.selected` SSE esemény → a transzcriptbe system sor: „Agent → Planner" (feedback, hogy a váltás megtörtént). |

### B. „Szöveg másolása/kijelölése a sidebarban"

**Mi a helyzet most:** a bubble `StyledText` (`Text` leszármazott) — **nem szelektálható**,
kijelölés nincs, copy gomb nincs.

**Terv (két réteg, a második az első biztosítéka):**

| # | Mit | Hogyan |
|---|-----|--------|
| B1 | Üzenetenkénti copy gomb | Hover/tap → `content_copy` ikon a bubble sarkában. `Quickshell.clipboardText = text` (a quickshell global singletonon van ilyen property, írható — `wl-copy` kellőszer nélkül). Mindig működik, ez a minimum. |
| B2 | Kijelölés egérrel | A bubble szövege `TextEdit`-re váltva: `readOnly: true`, `selectByMouse: true`, `textFormat: Text.MarkdownText` (a QQuickTextEdit tartalmazza a `MarkdownText` formátumot — ellenőrizendő élesben), `background: null`, szín/in méret megtartva. |
| B3 | ListView-drag vs. kijelölés konfliktus | **A legnagyobb UI-kockázat.** A ListView flick-je és a TextEdit egérhúzása ugyanazt az eseményt eszi. Terv: hosszú nyomás (≈350 ms) „kijelölési módba" kapcsol (`ListView.interactive = false`, a TextEdit `selectByMouse` be), kilépés: kattintás máshol / Esc / „Kész" chip. Rövid nyomás-húzás továbbra is görget. `TextEdit.copy()` a kijelölt részt a vágólapra teszi; B1 a teljes üzenetet. |
| B4 | Cod block külön copy | 2. lépés: a markdown `TextEdit` nem ad block-szintű gombokat — ha kell, a küldött/kapott szövegen egyszerű `` ``` ``-feldolgozással külön `codeRow` komponens + saját copy gomb (opcionális, B1/B2 után döntés). |

### C. „Vissza lehet menni az üzenetekhez" (scrollback)

**Mi a helyzet most:** `onCountChanged` → `positionViewAtEnd()`, és **minden**
`assistantText` delta ismét `positionViewAtEnd()`-et hív — felgörgetve az új stream azonnal
leránt a legaljára. Továbbá `HISTORY_LIMIT = 40`, csak szöveges `msg` kindok, nincs
időbélyeg, nincs görgetősáv.

**Terv:**

| # | Mit | Hogyan |
|---|-----|--------|
| C1 | Sticky-bottom logika | Csak akkor ugratunk legyalulra, ha `list.atYEnd` (vagy a felhasználó egyébként is lent van). Felgörgetve az új üzenet/stream **nem** mozdítja a nézetet; helyette lebegő „legújabb ↓" chip jelenik meg, az ugrat. |
| C2 | Görgetősáv | `StyledScrollBar { flickable: list }` a transcript doboz jobb oldalán (a komponens már létezik a repóban). |
| C3 | Régebbi üzenetek betöltése | chiefd: `GET /session/{id}/message?order=asc&limit=&cursor=` (a spec ad `limit/order/cursor/type` query-ket). Új socket-üzenet `loadOlder` → chiefd cursor-os lapot küld, `historyOld` frame-ként; QML: prepend `ListModel`-be, `contentY`-kompenzációval. |
| C4 | Gazdagabb history | A history frame hordozza: `messageID`, `time.created`, `kind` (msg/user/permission), és később tool részek is (lásd 3. szakasz). Így a visszanézés nem csak sima szöveg. |
| C5 | Navigáció billentyűről/wheelről | PageUp/PageDown, Home/End a transcript fókuszában (opencode `messages_page_*` paritás); a létező wheel-görgetés marad. |

---

## 1. Teljes opencode funkcionalitás → lefedettség

### 1.1 Session menedzsment

| opencode | API (élő spec) | Terv |
|----------|----------------|------|
| `/new` (session_new) | `POST /session` | **Kész** (header `add_comment` gomb). |
| `/sessions` (list, switch, resume) | `GET /session?limit&search&cursor&parentID` | **Sessions sheet** a model picker mintájára: cím, idő, agent, modell; váltás → `session.json` mentés, `POST /agent`+`POST /model`, history újratöltés, `status` broadcast. Keresés mező. |
| session rename (`ctrl+r`) | `PATCH /session/{id}` `{title}` | Session sheet sor hosszú-nyomás → szerkesztés. |
| session delete (`ctrl+d`) | `DELETE /session/{id}` | Session sheet sor → trash, megerősítéssel. |
| session fork | `POST /session/{id}/fork` `{before}` | Session sheet akció; az új session váltása. |
| session timeline / child-ok | `GET /session?parentID=` | 2. lépés (subagent sessionök böngészése). |
| `/undo`, `/redo` (git snapshot) | `POST /revert/stage`, `POST /revert/commit`, `DELETE /revert` | Header „visszavonás" ikon; **figyelem: a chiefd cwd=HOME, ami nem biztos, hogy git repo** → ha a revert hibát ad, csendben jelezzük a transzcriptbe. |
| `/compact` (`ctrl+x c`) | `POST /session/{id}/compact` | Header menü/ac + system sor a transzcriptben; `session.compaction.*` SSE figyelése. |
| `/export` | `GET /experimental/session/{id}/export` | Markdown lekérés → `Quickshell.clipboardText` (vagy fájlba mentés). |
| `/share` | **nincs a v2 specben** | Kihagyás (a docs említi, a tényleges spec nem tartalmazza — ha később megjelenik, opcionális). |
| timestamps toggle | — | C4-ben a `time.created` már jön; kapcsoló a headerben. |

### 1.2 Prompt-kiegészítők

| opencode | API | Terv |
|----------|-----|------|
| `@file` fuzzy keresés | `GET /api/fs/find?query=&limit=` + `GET /api/reference` (aliasök) | Input `@`-ra **autocomplete overlay** (a picker-ek sheet-mintájára, az input felett): gépelés közben tölt, Enter beszúrja; küldéskor `prompt.files[] = [{uri, name, mention}]`. |
| `!parancs` | `POST /session/{id}/shell` `{command}` | Ha a szöveg `!`-nel kezdődik, a chiefd a shell végpontnak küldi; az eredmény `kind: "tool"` sorral jön vissza. |
| `/` slash parancsok | `GET /api/command` (custom commandok) + beépítettek | `/` lenyomásra **command palette** overlay: beépítettek kliensoldalon (`/new`, `/compact`, `/undo`, `/export`, `/sessions`…), customokat a szerverről; választás → `POST /session/{id}/command {name, text}` vagy a lokális akció. |
| skills | `GET /api/skill` → `prompt.skills[]` | Command palette al-sor vagy `/skill` list; említés a promptban. |
| agent említés (`@chief`) | `prompt.agents[]` `{name, mention}` | Az autocompletes listában az agentek is szerepeljenek (subagent hívás). |
| prompt history (↑↓) | lokális | Az elküldött saját üzenetek listája (`PersistentProperties`), ↑/↓ a input üresen. |
| drag&drop kép, külső szerkesztő | — | **Kihagyás** (sidebar-os UX-ből indokoltan). |

### 1.3 Transzcripció gazdagítása (a legnagyobb érték-különbség)

Jelenleg a chiefd **csak** `session.text.delta`-t streameli; a TUI a többit is mutatja.

| opencode | API/SSE | Terv |
|----------|---------|------|
| reasoning/thinking blokk (`session.reasoning.*`) | `session.reasoning.started/delta/ended` | Új `kind: "reasoning"` — összecsukható „Thinking" sor (opencode-stílus), alapból rejtve, `/thinking` kapcsoló. |
| tool hívások (`/details`) | `session.tool.called/success/failed/progress` + `message.part.*` | Új `kind: "tool"` sor: eszköz-ikon (shell/edit/read/webfetch), név, státusz (spinner → ✓/✗), eltelt idő, kibontva input/output. Tömören: „Ran `ls -la`" egy sorban. |
| tool result a historyban | `GET /session/{id}/message` → `parts[]` (`type: tool/reasoning/text`) | A `send_history` újraépíti a teljes struktúrát (C4), nem csak a szöveget. |
| diff nézet | `GET /session/{id}/diff?from&to` | Szerkesztés után összecsukható diff-kártya a transzcriptben (piros/zöld sorok, monospace). |
| usage/költség (`ctrl+x s` status) | `session.usage.updated` SSE, `GET /session/{id}` → `tokens`, `cost` | Header státusz-pill alatt/lehetséges sora: `in/out/cache` token + $; élő frissítés. |
| todo lista | nincs a v2 specben | Kihagyás. |

### 1.4 Engedélyek (permission)

| opencode | API | Terv |
|----------|-----|------|
| Approve/Always/Reject | `POST /session/{id}/permission/{rid}/reply` `{decision: once\|always\|reject, message?}` | **Kész** (kártya + badge). A reply body `message` mezője opcionális — elhagyható. |
| `ctrl+f` fullscreen detail | — | A kártya „részletek" nyílja: az összes `resources` + a `save` minták (`Permission.Request.resources`, `.save`) megjelenítése, nem csak az első 5 sor. |
| mentett engedélyek kezelése | `GET /api/permission/saved`, `DELETE /api/permission/saved/{id}` | **„Always" szabályok listája** az agent sheet alján (vagy külön lap): lásd → törölhető. Ez választ adja az eddigi „mindig engedélyez" rejtélyre is: a mentett `always` szabályok innen láthatók/törölhetők. |

### 1.5 Model / agent / mode

| opencode | API | Terv |
|----------|-----|------|
| model list (`ctrl+x m`), keresés | `GET /api/model` | **Kész** (model picker + keresés + kulcskezelés). |
| provider auth (`/connect`) | auth.json írás | **Kész** (Manage keys). |
| agent list (`ctrl+x a`), cycle (`Tab`) | `GET /api/agent`, `POST /session/{id}/agent` | **Kész** (agent picker). `Tab`/`Shift+Tab` globális gyorsváltás hozzáadandó (opencode `agent_cycle`). |
| mode (plan/build, `Tab`) | — | A `planner` agent már a plan-mode; a Tab itt az agent-ciklus lesz (fenti sor). |
| variant (`ctrl+t`), favorite (`ctrl+f`), recent (`f2`) | `model.variants`, `POST /session/{id}/model {variant}` | **Alacsony prioritás** — a model sheet `free` sora után jöhet. |

### 1.6 Amit kihagyunk (indokoltan)

Pluginok, MCP-kezelő UI, LSP/formatter státusz, konzol, worktree-k, PTY/terminál,
pairing, OAuth bejelentkezés (a kulcs-beillesztés már megvan), theme-váltás (a sidebar
M3 téma követi a shellt), keybind-szerkesztő, `/init` guided setup (AGENTS.md a HOME-ban
amúgy is betölt), share (nincs API).

---

## 2. Protokoll-bővítés (chiefd ↔ AgentClient)

Új **kimenő** frame-ek:
`agentInfo {id, name, description, system}`,
`sessions [{id, title, time, agent, model, tokens, cost}]`,
`sessionSwitched {id, title}`,
`historyOld {messages[], cursor?, hasMore}`,
`reasoning {text, phase}`,
`toolCall {id, name, status, input, output, ms}`,
`diff {files[]}`,
`usage {input, output, cacheRead, cacheWrite, cost}`,
`commands [{name, description}]`,
`files [{path}]`,
`skills [{id, name, description}]`,
`savedPermissions [{id, action, resource, time}]`,
`toggled {key, on}`.

Új **bejövő** (socket) üzenetek:
`switchSession`, `renameSession`, `deleteSession`, `forkSession`, `compact`,
`undo`, `redo`, `export`, `runCommand`, `loadOlder {cursor}`, `queryFiles {q}`,
`listCommands`, `listSkills`, `savedPermissions`, `deleteSavedPermission`,
`setInstruction` (opcionális).

`history` frame **versionált**: `historyV2`-re váltás a QML-lel együtt (a régi
`sender/text` mezők megmaradnak a `msg` kindoknál, bővül `messageID/time/kind/parts`-szal).

---

## 3. Fázisok

**Fázis 0 — a három közvetlen kérés** (A, B, C fent):
- A1–A4 (agent info sheet, session instruction, safeguard, váltás-visszajelzés)
- B1–B3 (copy gomb, TextEdit kijelölés, hosszú-nyomás mód)
- C1–C3, C5 (sticky-bottom, scrollbar, loadOlder; C4 a historyV2-hoz kötött)
Becslés: ~2–3 munkanap, a B3 kijelölés-mód a kockázatos rész.

**Fázis 1 — session menedzsment**: sessions sheet (list/switch/rename/delete/fork),
compact, export, undo/redo (git-guarddal). ~2 nap.

**Fázis 2 — gazdag transzcript**: reasoning + tool SSE streamelés, historyV2
(parts újraépítés), tool/reasoning/kindok a ChatMessage-ben, diff-kártya, usage sor.
~3 nap (a chiefd SSE-kezelése + a QML új delegate-jei).

**Fázis 3 — prompt-paritás**: `@file` autocomplete, `/` command palette (+ custom
commandok, skills, agent-említés), `!shell`, prompt history. ~2–3 nap.

**Fázis 4 — polish**: permission „mindig" szabályok kezelőlapja, fullscreen permission
detail, Tab agent-ciklus, notification (Quickshell.Services.Notifications) permission/
kész válaszra, ha a panel zárva van, timestamps kapcsoló.

---

## 4. Kockázatok

1. **B3 (kijelölés vs. ListView flick)** — a legnagyobb UI-kockázat; ha a TextEdit
   egérhúzása nem egyeztethető össze a görgetéssel, a B1 copy gomb megmarad önálló
   megoldásként, a kijelölés pedig csak hosszú-nyomásra.
2. **HistoryV2 törés** — a `pushEntry`/`ListModel` szerepeinek bővítése + a hot-reload
   ragacsos modellje → teszt mindig **tiszta shell-újraindítással** (`caelestia shell -k`
   majd `-d`), nem hot-reloaddal.
3. **`/revert` nem-git cwd-n** — a chiefd HOME-ban fut; az undo/redo hibakezelést igényel.
4. **SSE eseménynevek verziófüggők** — a `session.tool.*`/`session.reasoning.*` neveket
   élő turn közben kell megerősíteni (a bináristringsből származnak), mielőtt a
   chiefd rájuk épít; fallback: a `GET /session/{id}/message` `parts[]` alapján
   turn végén felépített sorok.
5. **`textFormat: Text.MarkdownText` a TextEdit-en** — ellenőrizni élőben; ha nem
   működik, alternatíva: a `Text` (StyledText) + külön selection-overlay, vagy
   `RichText` konverzió.

## 5. Orchestrator: nonstop fleet felügyelet + menedzsment (ÚJ követelmény)

**Cél:** a chief nonstop fusson, felügyelje ÉS irányítsa a személyes opencode
sessionöket és a sajátjait is; fontos eredménynél/actionnél visszajelzzen;
bármikor válaszoljon up-to-date tudással; új feladatokat indítson, új agenteket
kiosztson, futtasson és felügyeljen.

### 5.1 Felderített környezet (élőben ellenőrizve)

| Dolog | Állapot |
|-------|---------|
| Személyes szerver | `opencode serve --service` (opencodes.service), **port dinamikus** — felderítés: `opencode service status` → `http://127.0.0.1:49374`; jelszó: `~/.config/opencode/service.json` (`password`) |
| Személyes sessionök | `GET /api/session?limit=` működik a személyesen is (build/plan sessionök, `agent`, `parentID`, `outcome`, `tokens`, `cost`, `time.updated` mezőkkel) |
| Személyes agentek | `GET /api/agent` → build (primary), general/explore (subagent), plan (primary), + rejtettek (title/summary/compaction) |
| **Globális SSE személyesen is** | `GET /api/event` → `session.tool.success`, `shell.exited` stb. **MINDEN session** eseménye jön, nem csak egyetlené — ez a felügyelet alapja |
| `GET /api/session/active` | `{sessionID: {type: "running"}}` — élőben futó sessionök pillanatképe |
| **`delivery: steer/queue`** | ✅ ÉLŐBEN TESZTELVE: `POST /prompt {text, delivery:"steer"}` futó turn közben → 200, az üzenet az inboxba kerül és a modell a következő lépésben megkapja. Ez teszi a chiefet "nonstop elérhetővé". |
| **Session instructions** | ✅ ÉLŐBEN TESZTELVE: `PUT /api/experimental/session/{id}/instructions/entries/{key}` → 204, `GET` visszaolvasja. Ide lehet írni a per-session kontextust. |
| Permission a személyesen | `GET /api/permission/request` üres lista → nincs függőben; ugyanaz a reply API mint a sajáton |
| Meglévő monitor | `oc-agent-monitor.service` (45s ciklus, `/tmp/opencode/agents-status.md`) — ps/sqlite logolás; **nem** csatlakozik API-hoz, a chiefd nem olvassa. Kiváltandó/fejlesztendő. |
| Duplikált sidebar instance | `opencodes.service` = elszigetelt sidebar-adatokkal, de a chiefd sajátot indít (4110). Két sidebar-adatbázis létezik — tisztázandó, hogy melyik az egyetlen forrás. |

### 5.2 Architektúra: két-rétegű fleet (terv)

**1. réteg — chiefd `FleetMonitor` (mindig fut, systemd `Restart=always`):**

- **Felderítés**: induláskor és 60s-ként `opencode service status` + `service.json`
  olvasás → személyes bázis URL + jelszó; ha a személyes service nem fut,
  `systemctl --user start opencodes` (ha kértük) vagy csendes "offline" állapot.
- **Kapcsolat**: második `OcClient` + **második SSE szál** a személyes szerverre
  (a chiefd saját 4110-es mellé). A személyes SSE globális, így egy szál
  lefedi az összes személyes sessiont.
- **Állapot-modell**: `fleet.json` (STATE_DIR) — minden sessionről:
  `{server: personal|sidebar, id, title, agent, running, outcome, tokens,
  cost, lastEvent, lastSeen}`. Forrás: SSE események + 15s-os
  `GET /api/session/active` + periódikus `GET /api/session` poll.
- **Küldés a sidebarnak**: új `fleet` frame (a fenti állapot tömörítve),
  push trigger: állapotváltozás (running→succeeded/failed), nem 15s tick.

**2. réteg — a chief (LLM) saját felügyeleti tool-al:**

- A chiefd **minden prompt ELŐTT** frissíti a session `instructions`-ébe
  (`entries/fleet`) a tömör fleet-pillanatképet (futó sessionök címe,
  agentje, állapota, legutóbbi eredmény) — így a modell minden válasznál
  up-to-date tudással rendelkezik, tool-hívás nélkül. (A korábbi
  `agents-status.md` ötlet API-alapú megvalósítása.)
- Opcionális 2b: `oc` parancs a chief shell tool-jából (`scripts/oc.sh`:
  curl a személyes API-hoz a jelszóval) — a chief maga kérdezhet rá
  részletekre (pl. `oc sessions`, `oc log ses_x`) és maga indíthat
  sessionöket. Ez a "kiosztás + felügyelet" tool-szintű útja.

### 5.3 Új socket-üzenetek (sidebar ↔ chiefd)

| Üzenet | Funkció |
|--------|---------|
| `fleet` (kimenő) | Fleet-pillanatkép: futó/utolsó sessionök mindkét szerverről |
| `fleetEvent` (kimenő) | Egy fontos esemény: `session.execution.succeeded/failed`, permission ask, tool hiba — transzcript system-sora + értesítés |
| `dispatch` (bejövő) | Új feladat indítása: `{server, agent, text, directory?}` → `POST /session` + `POST /prompt` (vagy `parentID`-vel subagentként) |
| `steer` (bejövő) | Üzenet küldése egy MÁR FUTÓ sessionbe: `{sessionID, text}` → `POST /prompt {delivery:"steer"}` |
| `interruptSession` (bejövő) | `{sessionID}` → `POST /session/{id}/interrupt` — bármelyik szerveren |
| `sessions` (kimenő) | Session-lista a Fleet sheethez (cím, agent, állapot, idő) — `GET /session` mindkét szerverről |

### 5.4 UI: Fleet sheet + fejléc-badge

- **Header badge**: futó sessionök száma (`fleet.runningCount`), kattintás →
  Fleet sheet. futás közben spinner.
- **Fleet sheet** (model/agent picker mintára, in-panel overlay, NEM popup):
  soronként session: állapot-pont (futó/végzett/hiba), cím, agent, utolsó
  aktivitás, token/költség. Akciók soronként: **steer** (üzenet a futóba),
  **interrupt**, **megnyitás** (ha sidebar-session → betöltés a transzcriptbe),
  és felül: **Új feladat** gomb → agent-választó + szövegmező → `dispatch`.
- **Transzcript system-sor**: `fleetEvent`-ek (`kind: "system"`) — pl.
  "✓ *Web* session befejezve (build, 34.2k tok)"; ez a "fontosabb
  eredményeknél visszajelzés".
- **Értesítés**: ha a panel zárva van, a quickshell notifications modulba
  kerülő esemény (a meglévő NotificationServer) — permission ask vagy
  session vége.

### 5.5 Nonstop válaszkészség (chief oldalon)

- A chiefd `handle_send` jelenleg **elutasítja**, ha `self.busy` ("abort first").
  Cserélni: busy közben `delivery: "steer"`-rel küldi a promptot → a chief
  válaszol a jelenlegi turn végén (vagy a modell a következő lépésben látja).
  Élőben tesztelve, működik.
- UI: busy közben a send gomb aktív marad, a küldött szöveg `queued`
  jelöléssel jelenik meg („a chief a válasz után foglalkozik vele" vagy
  steered esetén azonnal a modell elé kerül).
- `messageDone`-ig tartó turn-ok alatt is jöhet új kérdés → az nem
  `error`, hanem steer.

### 5.6 Nonstop felügyelet + visszajelzés (esemény-szűrő)

A chiefd SSE-kezelője MINDKÉT szerver eseményeit szűri (jelenleg csak a
saját sessionjéét figyeli):

| Esemény | Akció |
|---------|-------|
| `session.execution.succeeded/failed` | `fleetEvent` + transzcript-sor; ha ez a chief saját sessionje → a meglévő turn-zárás |
| `session.tool.failed` | `fleetEvent` (hiba) — a személyes sessionök eszközhibéi is látszanak |
| `permission.asked` (bármely szerver) | permission card a sidebarba + értesítés, ha panel zárva |
| `session.created`, `session.updated` | fleet állapot frissítés |
| `session.usage.updated` | token/költség frissítés a Fleet sorban |
| 15s poll: `GET /session/active` | Futó sessionök halmaza (SSE kiesés ellen is véd) |

**Visszajelzési csatornák prioritásban:** (1) transzcript system-sor,
(2) header badge számláló, (3) asztali értesítés panel-zárásnál,
(4) Fleet sheet részletei.

### 5.7 Új feladat, új agent kiosztása

- **Sidebarból**: Fleet sheet → „Új feladat" → agent-választó (személyes
  agentek: build/plan/general/explore + sajátok: chief/planner/unlocked) +
  szöveg → `dispatch {server, agent, text}` → chiefd `POST /session {agent}`
  + `POST /prompt`. `parentID` megadásával **subagentként** indítható egy
  meglévő session alá (opencode belső subagent-fája).
- **A chieftől**: ha a `scripts/oc.sh` tool megvan, a chief maga is
  indíthat (`oc dispatch --agent build --dir ~/projekt "csináld X"`),
  és a fleet instructions-ból tudja, mi fut.
- **Futtatás és felügyelet**: minden indított session a fleet.json-ba
  kerül, a Fleet sheet és a badge azonnal mutatja; a végéről
  `fleetEvent` + értesítés jön.

### 5.8 Tisztázandó kérdések (döntést igényelnek)

1. **Két sidebar instance**: az `opencodes.service` (4130, sidebar-adatokkal)
   és a chiefd saját 4110-es szervere párhuzamosan fut, két külön
   adatbázissal. Vagy az `opencodes.service` lesz a chiefd backingje
   (chiefd csatlakozik, nem indít sajátot), vagy az `opencodes.service`
   törlése. Javaslat: **chiefd csatlakozzon az opencodes.service-hez**
   (port 4130, `service.json` jelszó), ezzel megszűnik a duplikáció és a
   TUI-kból is látszik ugyanaz az állapot. *(Ez a 4110-es port- és
   spawn-logika átírását jelenti.)*
2. **Melyik a forrás a sidebar sessionre**: ha az `opencodes.service` marad,
   a sessionök onnan jönnek, a chiefd csak kliens.
3. **Személyes szerver automatikus indítása**: ha a személyes service nem
   fut, indítsa-e a chiefd (`systemctl --user start`), vagy csak jelezze.
4. **`oc.sh` tool vs. instructions-only**: a fleet instructions elegendő
   olvasáshoz; a command indításhoz és részletes kérdezéshez kell a
   `scripts/oc.sh` (vagy egy custom opencode tool). Mi legyen?

### 5.9 Fázis-bontás (kiegészítés a 3. szakaszhoz)

- **Fázis 5 — Fleet alapok**: személyes kapcsolat (felderítés + SSE),
  `fleet.json`, `fleet`/`fleetEvent` frame-ek, header badge, Fleet sheet
  olvasási nézet. ~2–3 nap.
- **Fázis 6 — Nonstop chief**: `handle_send` steer-re cserélése,
  `dispatch`/`steer`/`interruptSession` üzenetek, Fleet sheet akciók
  (új feladat, steer, interrupt), értesítések. ~2 nap.
- **Fázis 7 — Fleet intelligencia**: fleet instructions injektálás minden
  promptba, `oc.sh` tool (ha igen a 5.8/4 kérdés), rendszeres
  session-poll finomhangolás, költség/token összesítő. ~2 nap.

---

## 6. Előző session nyitott tételei (háttér)

- A korábbi időzített permission-teszt (`date +%s && echo noperm-test-9931`) kiértékelése —
  a `savedPermissions` lista (1.4) pont azt tisztázza, hogy van-e mentett `always` szabály.
- Commitok: (a) MiniDash `mirrored` módosítás külön commit; (b) chat feature külön
  (QML + chiefd + agent `.md` + ez a tervdokumentum).
