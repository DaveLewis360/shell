# Terv: a fork professzionálissá tétele

Cél: minden saját változtatás legyen jól kivehető, és az eredeti upstream kód
maradjon meg mindenhol, ahol csak lehet.

Készült: 2026-07-30 · bázis: `06b4fe07` (v2.2.0) · fork: 12 commit az upstream felett

---

## 1. Mért állapot

A fork **902 hozzáadott QML sort** tartalmaz. Gépi osztályozással (a régi és új
sorok tengely-tükrözéses összevetésével):

| kategória | sor | arány |
|---|---:|---:|
| valódi változás | 668 | 74% |
| tisztán tengelycsere (`Column`↔`Row`, `x`↔`y`, `Width`↔`Height`) | 197 | 21% |
| **regresszió** (`root.Config` → `Config`) | 34 | 3% |
| zaj (azonos sor) | 3 | 0% |

Felület: 3 fork-only fájl + **35 módosított upstream fájl**.

### A döntő megállapítás

**Az upstream a fork által érintett MINDEN fájlt aktívan fejleszti** — 6 hónap
alatt fájlonként 9–35 commit:

| fájl | upstream commit / 6 hónap |
|---|---:|
| `modules/drawers/ContentWindow.qml` | 35 |
| `modules/sidebar/NotifGroupList.qml` | 28 |
| `modules/lock/Media.qml` | 25 |
| `modules/dashboard/Wrapper.qml` | 20 |
| `modules/bar/components/workspaces/SpecialWorkspaces.qml` | 19 |
| `modules/bar/Bar.qml` | 15 |
| `modules/background/Wallpaper.qml` | 15 |
| … a legkevesebb is 9 | |

Ebből következik, hogy **a „másoljuk a fájlt a `custom/`-ba" stratégia rossz**:
fájlonként 9–35 commit upstream javítást vágnánk el. Meglévő upstream
komponensre a merge az egyetlen ésszerű út — a cél tehát nem a diff
*áthelyezése*, hanem a *csökkentése*.

---

## 2. Azonnal eltávolítható: 37 sor, nulla kockázattal

### 2.1 A `root.Config` → `Config` regresszió (34 sor, 8 fájl)

A fork több helyen levette a `root.` prefixet a `Config` elől. Ez **nem
egyszerűsítés, hanem hiba**: a `Config` egy attached property, ami a szülő
objektumon keresztül örökli a képernyőt. Csupasz `Config`-nál egy nem-`Item`
szülőn (pl. `ScriptModel`, `Connections`) ez nem működik, és a C++ getter
csendben a globális configra esik vissza:

```cpp
// plugin/src/Caelestia/Config/configattached.cpp
if ((m_complete || !qobject_cast<QQuickItem*>(parent())) && parent())
    qCWarning(lcConfig, "Config.%s accessed without a screen set on %s", ...);
return GlobalConfig::instance()->name();   // <-- globális fallback
```

Következmény: **per-monitor config nem érvényesül**, és a logban jelenleg
**67 `without a screen set` figyelmeztetés** van.

| fájl | regressziós sor |
|---|---:|
| `modules/utilities/RecordingDeleteModal.qml` | **22** ← a fájl 100%-a ez |
| `modules/bar/components/workspaces/ActiveIndicator.qml` | 5 |
| `modules/bar/components/workspaces/SpecialWorkspaces.qml` | 4 |
| `modules/bar/components/ActiveWindow.qml` | 2 |
| `modules/bar/Bar.qml` | 1 |
| `modules/bar/components/workspaces/Workspace.qml` | 1 |
| `modules/sidebar/NotifGroupList.qml` | 1 |
| `modules/utilities/toasts/Toasts.qml` | 1 |

**Teendő:** mind visszaállítani upstream formára. Három fájl (`RecordingDeleteModal`,
`NotifGroupList`, `Toasts`) ezzel **teljesen eltűnik a diffből**.

### 2.2 Zaj (3 sor)

- `modules/drawers/Exclusions.qml` — a régi és új sor **azonos**
- `modules/bar/BarWrapper.qml`, `modules/bar/components/StatusIcons.qml` — 1-1 azonos sor
- `modules/dashboard/media/BackgroundShapes.qml` — `Players.active?.isPlaying ?? false`
  → `Players.active ? Players.active.isPlaying : false` (szemantikailag azonos,
  csak elhagyja az optional chainingot)

**Eredmény:** 38 → **35 módosított fájl**, 902 → **865 sor**, és eltűnik 67 futásidejű
figyelmeztetés.

---

## 3. A 197 soros tengelycsere: mit lehet vele tenni

Ez a fork gerince: a vertikális bar horizontálissá tétele. **Kívülről nem
megoldható**, mert `ColumnLayout` → `RowLayout` szerkezeti csere — futásidőben
egy layout típusa nem változtatható meg. Az `ShellState.componentsFor()` +
`find(objectName)` API (lásd 4. pont) property-ket tud állítani, layout-típust
nem.

Három lehetőség, őszintén:

| út | diff | kockázat | értékelés |
|---|---|---|---|
| **A.** marad ahogy van, `rerere`-vel | 197 sor | alacsony | **ez a jelenlegi, és működik** |
| **B.** upstream PR: bar orientáció opció | 0 sor | — | **a végleges megoldás, ha beveszik** |
| **C.** fork-másolat `custom/`-ba | ~0 upstream sor | **magas** | elvágja a 9–35 upstream commitot |

A **C. utat elvetem** a 1. pont mérése alapján.

### Amit az A. úton javítani lehet

A 197 sor nem csökkenthető, de **rendszerezhető**. Jelenleg szétszórt, jelöletlen
szerkesztések. Javaslat: minden tengelycserés hunk kapjon egyetlen rövid
jelölést, hogy merge közben egy pillantással eldönthető legyen:

```qml
// [fork:axis] vízszintes bar
```

Ez ~30 komment-sor (nem 197, mert hunk-onként egy). Cserébe merge-nél nem kell
újra kitalálni, mi miért van. **Fontos:** csak a tengelycserés hunkokra, mert a
komment a módosított kód mellé kerülve növeli a konfliktus-felületet.

---

## 4. Amit az upstream ma már kínál: `ShellState`

Az upstream `04cb43ff` („improve state handling & add component hooks") committal
valódi kiterjesztési API-t kapott:

```qml
ShellState.componentsFor(screen)      // slotok: background, rootWindow,
                                      //         interactionWrapper, bar, panels
ShellState.componentsFor(s).find("taskbarClock", bar)
ShellState.componentsFor(s).findAll(name, root)
ShellState.componentsFor(s).findMatching(pattern, root)
```

És minden bar-entry kapott `objectName`-et: `taskbarLogo`, `taskbarWorkspaces`,
`taskbarActiveWindow`, `taskbarTray`, `taskbarClock`, `taskbarStatusIcons`,
`taskbarPowerButton`.

**Mire jó:** egy `custom/` komponens megtalálhat és *olvashat* upstream
komponenseket anélkül, hogy azok fájljait szerkesztenénk. A `MiniDash` ma a
`Bar.qml`-ből kap `rightPartX` / `workspacesX` / `workspacesWidth` property-ket
(+62 valódi sor a `Bar.qml`-ben) — ezek egy része kivezethető ide.

**Mire nem jó:** layout-típus cserére, és olyan property-kre, amiket a
komponens maga kötött (`readonly`, vagy saját binding).

---

## 5. Upstream PR jelöltek

Ha ezekből bármelyik bekerül, a fork véglegesen zsugorodik.

| # | mit | fork-nyereség | esély |
|---|---|---:|---|
| 1 | **Album art fallback** (`Players.lastArtUrl`) — objektív hibajavítás: playerváltásnál nem villog el a borító | 27 sor, 3 fájl | **jó** |
| 2 | **`bar.workspaces.background`** bool opció — a `tray` és `clock` szekcióban MÁR van `background` kulcs, ez csak követi a mintát | 1 sor | **jó** |
| 3 | **Bar orientáció opció** | **197 sor** | közepes |
| 4 | Videó wallpaper támogatás | ~150 sor | alacsonyabb |

A 2. a legjobb ár/érték: triviális PR, és pontosan illeszkedik a meglévő
config-sémába.

A 3. a nagy tét. Érv mellette: az upstream épp most csinálta a bart
konfigurálható entry-listává (`bar.entries`), és épp most nyitja kiterjeszthetővé
(`feat/plugins`). Ellenérv: a `63da6361` („internal: bar only vertical",
2025-05-27) committal szándékosan *kivették* a horizontális támogatást.
→ **Előbb issue, ne kód.**

---

## 6. Plugin migráció (amikor a `feat/plugins` mainbe kerül)

Az upstream `feat/plugins` branchén (utolsó commit: 2026-07-29) kész plugin
infrastruktúra van: `manifest.json`, belépési pontok (`BarEntry`, `BarPopout`,
`StatusIcon`, `QuickToggle`, `DashboardTab`, `Custom`), plugin-szintű
beállítások + beállítás-UI, hot reload, Nexus kezelőfelület.

Ami átvihető:

| fork-elem | belépési pont | sor |
|---|---|---:|
| `custom/MiniDash.qml` | `BarEntry` + `BarPopout` | 208 |
| Clock dátum-kiegészítés | saját `BarEntry` (a beépített kikapcsolva) | 17 |

Ami **nem**: a tengelycsere, a videó wallpaper, az album art fix — ezekre nincs
belépési pont.

Kockázat: a branch nincs beolvasztva és aktívan változik. **Ne építsünk rá
addig**, csak tartsuk szemmel.

---

## 7. Végrehajtási sorrend

1. **Regresszió + zaj visszaállítása** (37 sor) — azonnal, nulla kockázat.
   Ellenőrzés: a `without a screen set` figyelmeztetések eltűnnek a logból.
2. **Tengelycserés hunkok jelölése** `// [fork:axis]`-szal (~30 komment).
3. **`fork-diff --files` újramérés** — a szám dokumentáltan csökken.
4. **Upstream issue** a bar orientációról (3. PR jelölt) — kód nélkül, először
   kérdés.
5. **PR: `bar.workspaces.background`** (2. jelölt) — kis, könnyen elfogadható.
6. **PR: album art fallback** (1. jelölt).
7. **`MiniDash` property-k kivezetése** `ShellState`-re, ahol lehet — a
   `Bar.qml` 62 valódi sorának csökkentése.
8. **Plugin migráció** — csak a `feat/plugins` beolvasztása után.

Az 1–3. lépés a fork mai állapotán javít, mérhetően. A 4–6. az egyetlen út a
tartós zsugorodáshoz. A 7–8. akkor jön, ha az upstream odaér.

---

## Amit szándékosan NEM javaslok

- **Fájl-másolás `custom/`-ba** meglévő upstream komponensekhez — a 1. pont
  mérése szerint fájlonként 9–35 upstream commitot vágna el.
- **`// [FORK]` jelölés minden hunkra** — ~580 komment-sor, és pont a módosított
  kód mellé kerülve *növeli* a konfliktus-felületet. Helyette: `fork-diff`
  (gitből számol, mindig pontos) + jelölés csak a tengelycserés hunkokra.
- **A fork történetének átírása** topikus commitokra — a merge-alapú
  munkafolyamathoz a `rerere` többet ad, és a history-átírás
  `--force-with-lease`-t igényel minden alkalommal.
- **HyDE-stílusú `.conf` → `.lua` fordítás** a caelestia oldalon — külön
  tanulság: a `translate_hypr_lua.py` a HyDE profilon 114 hibás keybindet
  generált, mert nem kezelte a `bindd` szintaxist.
