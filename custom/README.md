# `custom/` — a fork saját komponensei

Ide tartozik **minden olyan komponens, ami csak ebben a forkban létezik**, és
nem az upstream fájljainak módosítása. Ezek a fájlok upstream merge során
soha nem konfliktusolnak, mert az upstream nem is tud róluk.

## Bar mód váltása

A fork vízszintes barja és az eredeti caelestia vertikális barja **egymás
mellett él**. Váltás futás közben, újraindítás nélkül:

```bash
barmode              # aktuális mód
barmode h            # vízszintes (fork)
barmode v            # vertikális (eredeti caelestia)
barmode toggle
```

Ez a `~/.config/caelestia/extras.json` fájlt írja:

```json
{
    "bar": { "horizontal": true }
}
```

### Miért külön fájl, és nem a `shell.json`?

Az upstream C++ `ConfigObject` **csak a sémában definiált kulcsokat teszi ki**
QML property-ként. A `6e570081` commit óta az ismeretlen kulcsok *megmaradnak*
mentéskor (`mergeUnknownKeys`), de nem lesz belőlük olvasható property. Ezért
a fork beállításai külön fájlban élnek — így nulla ütközés az upstream mentési
ciklusával, és nem kell hozzá upstream-módosítás.

Olvasó: `custom/ExtrasConfig.qml` (`FileView` + `watchChanges`, ezért élő).

## Használat

A Quickshell a shell gyökerét `qs` névtérként teszi elérhetővé:

```qml
import qs.custom

MiniDash { }
```

## Konvenció

- **Ide kerül:** teljesen új komponens, ami nem létezik upstreamben.
- **NEM ide kerül:** upstream komponens módosítása. Azt a helyén kell
  szerkeszteni — lásd a `CUSTOMIZATIONS.md`-t, hogy miért.

## Mit tartalmaz

| Fájl | Mi ez |
|---|---|
| `ExtrasConfig.qml` | A fork beállításai (`extras.json`) |
| `MiniDash.qml` | Kompakt dashboard a bar mellett |
| `bar/H*.qml` | A vízszintes bar és komponensei — az upstream `modules/bar/` másolatai, átméretezve. Eredetük és a másolás alapja: `bar/VENDORED.json` |

## A `custom/bar/` másolatok árnyoldala

A vízszintes bar `Column`→`Row`, `y`↔`x` átalakítás, ami upstream komponensek
*belső* layoutját írja át — azt kívülről nem lehet felülülírni, csak a fájl
lemásolásával. Cserébe az upstream fájlok érintetlenek maradnak (nincs merge
konfliktus), viszont a másolatok **csendben elavulnak**, ha upstream javít
bennük valamit.

Ezért figyelni kell rájuk:

```bash
fork-diff          # mit módosít a fork összesen
fork-diff --files  # fájlonkénti bontás
```

## A drawers réteg orientációfüggő

A bar körüli helyfoglalás és a hover-zónák nem másolhatók ki, mert az upstream
`modules/drawers/` fájljaiban élnek. Ezek a fork-ban **feltételesek** lettek
(`bar.horizontal ? … : …`), így mindkét mód működik ugyanabból a kódból:

`BarWrapper.qml`, `Exclusions.qml`, `Panels.qml`, `Regions.qml`,
`Interactions.qml`, `ContentWindow.qml`

> **Figyelem:** QML-ben az `anchors.bottom: cond ? parent.bottom : undefined`
> **nem törli** az anchort — a wrapper mindkét élre felfeszül. Ezért itt
> mindenhol explicit `x`/`y`/`width`/`height` van feltételes anchor helyett.
