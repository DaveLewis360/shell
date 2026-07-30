# `custom/` — a fork saját komponensei

Ide tartozik **minden olyan komponens, ami csak ebben a forkban létezik**, és
nem az upstream fájljainak módosítása. Ezek a fájlok upstream merge során
soha nem konfliktusolnak, mert az upstream nem is tud róluk.

## Használat

A Quickshell a shell gyökerét `qs` névtérként teszi elérhetővé, így innen
minden komponens importálható:

```qml
import qs.custom

MiniDash { }
```

## Konvenció

- **Ide kerül:** teljesen új komponens, ami nem létezik upstreamben.
- **NEM ide kerül:** upstream komponens módosítása. Azt a helyén kell
  szerkeszteni — lásd a `CUSTOMIZATIONS.md`-t, hogy miért.

## Miért nem kerül ide minden?

A fork gerince a **horizontális bar** átalakítása: `Column`→`Row`, `y`↔`x`,
`implicitWidth`↔`implicitHeight`. Ez upstream komponensek *belső* layoutját
írja át, amit kívülről nem lehet felülírni — csak a fájl teljes lemásolásával.
A másolás viszont rosszabb, mint a merge: onnantól nem kapnád meg az upstream
javításait abban a fájlban.

Ezért ezek a módosítások a helyükön maradnak, és a merge-t a `rerere`
(rögzített konfliktus-feloldások) + a `shell-sync-upstream` script kezeli.

Mennyi tartozik melyik kategóriába:

```bash
fork-diff          # összefoglaló
fork-diff --files  # fájlonkénti bontás
```
