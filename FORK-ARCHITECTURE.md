# Architektúra: publikálható kiegészítés vs. patch-készlet

Kérdés: lehet-e a fork valódi *kiegészítés* — az upstream fájlok érintetlenül,
és csak 1-2 új switch a settingsben?

Válasz: **részben, és a mérések pontosan megmutatják, hol a határ.**

---

## Mit mértem meg

### 1. A saját config-kulcsok MEGMARADNAK ✅

Az upstream `6e570081` („preserve unknown config keys on save") committal a
`RootConfig` megőrzi az ismeretlen kulcsokat (`mergeUnknownKeys`,
`m_lastLoadedJson`).

Élesben ellenőrizve: beírtam a `shell.json`-ba egy `myCaelestiaTest` blokkot,
újraindítottam a shellt (ami mentéskor eldobhatta volna) — **megmaradt**.

→ Egy kiegészítés **ma is tarthatja a saját beállításait** a `shell.json`-ban a
maga névterében, upstream-módosítás nélkül.

### 2. Van komponens-kereső API ✅

Az upstream `04cb43ff` („add component hooks") committal:

```qml
ShellState.componentsFor(screen)          // slotok: background, rootWindow,
                                          //   interactionWrapper, bar, panels
ShellState.componentsFor(s).find("taskbarClock", bar)
ShellState.componentsFor(s).findAll(name, root)
ShellState.componentsFor(s).findMatching(pattern, root)
```

És minden bar-entry kapott `objectName`-et (`taskbarLogo`, `taskbarWorkspaces`,
`taskbarClock`, …).

→ Egy kiegészítés **megtalálhatja és olvashatja** az upstream komponenseket.
Property-ket állítani is tud, ha azokat a komponens maga nem kötötte le.

### 3. A layout-orientáció NEM váltható futásidőben ❌

Ez a döntő korlát. Lemértem egy izolált Quickshell teszttel:

| megközelítés | eredmény |
|---|---|
| `GridLayout { flow: vertical ? TopToBottom : LeftToRight }` | **nem vált** — `40x45` → `40x45`, a gyerekek helyben maradnak |
| `Loader { sourceComponent: vertical ? colComp : rowComp }` | **működik** — `40x45` → `85x20` |

Tehát a `ColumnLayout` → `RowLayout` csere csak a layout **újraépítésével**
lehetséges, bindolt property-vel nem. Kívülről, futásidőben pedig egy meglévő
layout típusa egyáltalán nem változtatható.

Az upstream bar-fája ráadásul **129 tengely-érzékeny sort** tartalmaz 12 fájlban:

| fájl | tengely-érzékeny sor |
|---|---:|
| `components/workspaces/SpecialWorkspaces.qml` | 23 |
| `components/StatusIcons.qml` | 18 |
| `components/Tray.qml` | 17 |
| `components/Clock.qml` | 16 |
| `components/ActiveWindow.qml` | 13 |
| `Bar.qml` | 11 |
| `BarWrapper.qml` | 8 |
| workspaces/{Workspace,ActiveIndicator,OccupiedBg,Workspaces} | 19 |
| `components/Power.qml` | 4 |

→ A **horizontális bar nem tud kiegészítés lenni**. Ehhez az upstreamnek kell
orientáció-opciót szállítania.

### 4. Az upstream minden érintett fájlt aktívan fejleszt ❌

6 hónap alatt fájlonként 9–35 commit. Ezért a „másoljuk a fájlt a `custom/`-ba"
út rossz: silent drift lesz belőle, és elvágja az upstream javításokat. A patch
ezzel szemben *konfliktust* ad — ami információ, nem baj.

---

## Következtetés: két külön termék

A fork mai tartalma nem egy termék, hanem kettő, és **érdemes szétvágni**.

### Termék A — `caelestia-extras` (valódi kiegészítés)

Csak **új fájlok**, nulla upstream módosítás. Bármely caelestia verzióval megy,
frissítésnél nincs teendő. **Ez publikálható a legkönnyebben.**

| tartalom | sor | belépési pont |
|---|---:|---|
| MiniDash widget | 208 | `BarEntry` + `BarPopout` (plugin), addig `custom/` |
| Clock dátummal | 17 | saját `BarEntry`, a beépített kikapcsolva |
| saját settings | — | `shell.json` → `extras.*` névtér (ellenőrizve: megmarad) |

Beállítások a `shell.json`-ban:

```json
"extras": {
  "miniDash": { "enabled": true, "showMedia": true },
  "clockDate": { "enabled": true, "format": "ddd d" }
}
```

Amikor a `feat/plugins` mainbe kerül, ez `manifest.json`-os pluginná alakul,
saját `settingsUi`-val — és akkor a switchek **a Nexus Plugins oldalán**
jelennek meg, pontosan úgy, ahogy szeretnéd.

### Termék B — `caelestia-horizontal` (patch-készlet)

A horizontális bar. **Nem lehet kiegészítés** (lásd 3. pont), tehát vállaltan
patch-készlet: 197 sor, 12–20 upstream fájlban.

Publikálási forma: git branch vagy `.patch` sorozat + install script, ami
alkalmazza. Frissítés: `rebase`/`merge` + `rerere`.

Őszintén kommunikálva: „ez patcheli a caelestiát, mert az upstream vertical-only".

---

## Az upstream PR-ok, amik A-ba olvasztják B-t

Sorrend ár/érték szerint:

| # | PR | méret | mit szabadít fel |
|---|---|---|---|
| 1 | `objectName` a wallpaper Loaderre (`Background.qml:42`) | 1 sor | a videó wallpaper kívülről cserélhetővé válik |
| 2 | `bar.workspaces.background` bool | 1 sor | 1 sor a forkból (a `tray`/`clock` szekcióban MÁR van ilyen kulcs) |
| 3 | album art fallback (`Players.lastArtUrl`) | 27 sor | 27 sor + objektív bugfix |
| 4 | **bar orientáció opció** | ~129 sor upstreamben | **a teljes 197 soros B termék** |

A 4. a nagy tét. Technikai vázlat, amit a mérés alátámaszt: a `Bar.qml`
layoutja `Loader`-be kerül két komponenssel (`ColumnLayout` / `RowLayout`), a
gyerek-entryk pedig egy `readonly property bool vertical: Config.bar.vertical`
alapján igazodnak. A `Loader` út bizonyítottan működik.

Ellenérv, amit tudni kell: a `63da6361` („internal: bar only vertical",
2025-05-27) committal az upstream **szándékosan** vette ki a horizontális
támogatást. → **Előbb issue, ne kód.**

---

## Install script vázlat

```bash
# caelestia-extras (Termék A) — nulla upstream módosítás
install-extras() {
    # 1. a komponensek a plugin/custom könyvtárba
    mkdir -p ~/.config/caelestia/plugins/davelewis360/extras
    cp -r components/* ~/.config/caelestia/plugins/davelewis360/extras/
    cp manifest.json  ~/.config/caelestia/plugins/davelewis360/extras/

    # 2. a config-kulcsok BEOLVASZTÁSA (nem felülírás!) — jq-val
    jq -s '.[0] * .[1]' ~/.config/caelestia/shell.json defaults.json \
        > /tmp/merged && mv /tmp/merged ~/.config/caelestia/shell.json

    # 3. bar entry beszúrása, ha még nincs
    #    (a bar.entries egy rendezett lista, id-vel)
}
```

A lényeg: **`jq -s '.[0] * .[1]'`** — a felhasználó meglévő beállításait nem
tapossa le, csak hozzáolvasztja a sajátjait. Ez azért működik, mert az upstream
megőrzi az ismeretlen kulcsokat (1. pont).

---

## Amit NEM szabad

- **Az upstream fájlok másolása `custom/`-ba** — 9–35 commit/fájl elvágása
  (4. pont).
- **A horizontális bart kiegészítésként hirdetni** — technikailag nem az
  (3. pont). Két külön termék, két külön ígéret.
- **Install script, ami felülírja a `shell.json`-t** — a felhasználó
  beállításait kell megőrizni, ezért `jq` merge, nem `cp`.
