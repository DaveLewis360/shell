# Fork testreszabások — DaveLewis360/shell

Ez a dokumentum leírja, **mit** módosít ez a fork a `caelestia-dots/shell`
upstreamhez képest, és **melyik változtatás mennyire konfliktusveszélyes**
egy upstream merge során. Merge előtt ezt érdemes átfutni.

Utolsó frissítés: 2026-07-29
Bázis: `v2.1.0` vonal (merge-base `145a6795`, 2026-06-28)
Diff felület: **38 fájl, +1005 / -523**

---

## A legfontosabb strukturális tény

**Az upstream szándékosan vertikális-only.**

A `63da6361` *"internal: bar only vertical"* commit (2025-05-27, benne van a mai
`main`-ben) eltávolította a horizontális bar támogatását, és a `Box` /
`BoxLayout` / `AnchorText` orientáció-agnosztikus widgeteket is törölte.
A mai `shell.json` sémában **nincs** bar-orientáció opció.

Ez a fork **visszahozza a horizontális bart**. Ez tehát nem átmeneti
eltérés, hanem tartós divergencia — és pontosan azokban a fájlokban,
amelyeket az upstream is folyamatosan csiszol.

Következmény: ezekben a fájlokban **minden** upstream frissítésnél
konfliktus várható. Ezért van bekapcsolva a `rerere` (lásd lentebb).

---

## 1. csoport — Horizontális bar átalakítás (KONFLIKTUS-VESZÉLY: NAGY)

Mechanikus, de mindenhol szétszórt átalakítás:
`Column`→`Row`, `y`↔`x`, `implicitWidth`↔`implicitHeight`,
`horizontalCenter`→`verticalCenter`, `top/bottom`→`left/right`.

| Fájl | +/- | Megjegyzés |
|---|---|---|
| `modules/bar/Bar.qml` | +74/-21 | fő layout Column→Row |
| `modules/bar/BarWrapper.qml` | +21/-16 | méretezés tengelycsere |
| `modules/bar/components/Tray.qml` | +20/-20 | `nonAnimHeight`→`nonAnimWidth` |
| `modules/bar/components/StatusIcons.qml` | +18/-18 | tisztán tengelycsere |
| `modules/bar/components/ActiveWindow.qml` | +13/-25 | |
| `modules/bar/components/workspaces/ActiveIndicator.qml` | +14/-14 | `y`→`x`, mask irány |
| `modules/bar/components/workspaces/Workspace.qml` | +13/-13 | tisztán tengelycsere |
| `modules/bar/components/workspaces/OccupiedBg.qml` | +6/-6 | tisztán tengelycsere |
| `modules/bar/components/workspaces/Workspaces.qml` | +5/-5 | tisztán tengelycsere |
| `modules/bar/components/workspaces/SpecialWorkspaces.qml` | +56/-47 | tengelycsere + logika |
| `modules/bar/components/Power.qml` | +4/-4 | |
| `modules/bar/popouts/ClipWrapper.qml` | +12/-11 | popout pozicionálás |
| `modules/drawers/ContentWindow.qml` | +38/-68 | panel geometria |
| `modules/drawers/Interactions.qml` | +48/-28 | hover/klikk zónák |
| `modules/drawers/Regions.qml` | +7/-7 | input régiók |
| `modules/drawers/Exclusions.qml` | +1/-1 | layer-shell exclusion zone |
| `modules/drawers/Panels.qml` | +2/-1 | |
| `modules/osd/Wrapper.qml`, `modules/osd/Content.qml` | +6/-8 | OSD pozíció |

**Merge taktika:** ha upstream ugyanezt a sort módosítja, szinte mindig
a **saját oldal geometriája + upstream logikai változása** a helyes eredmény.
Vagyis: vedd át az upstream érdemi változtatását, de tartsd meg a tengelycserét.
A `rerere` az első ilyen döntés után emlékezni fog rá.

---

## 2. csoport — Saját funkciók (KONFLIKTUS-VESZÉLY: KIS)

Új fájlok, illetve jól elszigetelt kiegészítések. Ezek ritkán konfliktusosak.

| Fájl | +/- | Mit ad |
|---|---|---|
| `modules/bar/components/MiniDash.qml` | +243/-0 | **ÚJ** — mini dashboard a barban |
| `modules/bar/popouts/Background.qml` | +79/-0 | **ÚJ** — üveg/blur popout háttér |
| `modules/bar/components/Clock.qml` | +20/-71 | napnév + hónap napja az óra mellett |
| `services/Players.qml` | +21/-0 | `lastArtUrl` — borítókép megtartása |
| `utils/Images.qml` | +10/-0 | segédfüggvények |
| `components/widgets/CoverArt.qml` | +1/-1 | fallback `lastArtUrl`-re |
| `modules/lock/Media.qml` | +1/-1 | fallback `lastArtUrl`-re |

---

## 3. csoport — Videó wallpaper támogatás (KONFLIKTUS-VESZÉLY: KÖZEPES)

Az upstream csak képeket támogat; ez a fork videót is.

| Fájl | +/- |
|---|---|
| `modules/background/Wallpaper.qml` | +116/-42 |
| `services/Wallpapers.qml` | +26/-33 |
| `modules/nexus/common/WallItem.qml` | +36/-1 |

**Figyelem:** az upstream aktívan fejleszti a `nexus` modult
(`feat/nexus`, `feat/m3-revamp` branchek), ezért a `WallItem.qml`
konfliktusveszélye nőhet.

---

## 4. csoport — Apró vizuális finomítások (KONFLIKTUS-VESZÉLY: KIS)

| Fájl | +/- |
|---|---|
| `components/controls/FilledSlider.qml` | +51/-27 |
| `modules/utilities/RecordingDeleteModal.qml` | +22/-22 |
| `modules/dashboard/Wrapper.qml` | +2/-1 |
| `modules/dashboard/media/BackgroundShapes.qml` | +2/-2 |
| `modules/lock/NotifGroup.qml` | +2/-2 |
| `modules/sidebar/NotifGroupList.qml` | +1/-1 |
| `modules/utilities/toasts/Toasts.qml` | +1/-1 |
| `shell.qml` | +4/-4 |

---

## Merge munkafolyamat

Használd a helper scriptet — minden lépése visszavonható:

```bash
~/dotfiles/scripts/shell-sync-upstream            # merge az upstream/main-re
~/dotfiles/scripts/shell-sync-upstream --tag v2.2.0   # konkrét tagre
~/dotfiles/scripts/shell-sync-upstream --abort    # félbehagyott merge eldobása
~/dotfiles/scripts/shell-sync-upstream --undo     # BEFEJEZETT merge visszavonása
```

A script minden futás előtt egy `pre-merge/<időbélyeg>` visszaállítási pontot
hoz létre a `refs/backup/` névtérben, így a merge mindig egy paranccsal
visszavonható.

> **Miért nem tag?** A `CMakeLists.txt` a verziót a
> `git describe --tags --abbrev=0`-ból veszi. Egy saját tag (pl. egy mentés)
> elárnyékolná a `v2.x.y` verziótageket, és a build elhasalna
> (`VERSION "restore-point/..." format invalid`). A `refs/backup/` refeket a
> `git describe` nem látja, de a `git reset --hard refs/backup/...`,
> a `git log` és a `git branch` teljesen működik velük.

### Ami segít a konfliktusoknál

- **`rerere`** (be van kapcsolva): minden feloldást megjegyez, és a
  következő merge-nél automatikusan alkalmazza. Egy konfliktust elég
  egyszer megoldani.
- **`merge.conflictStyle=zdiff3`**: a konfliktus-markerek a közös őst is
  megmutatják, nem csak a két oldalt — így látod, mit változtatott
  valójában az upstream.
- **`diff.algorithm=histogram`**: kevesebb hamis konfliktus QML-ben.

### Hosszú távú egyszerűsítési lehetőség

Ha az 1. csoport konfliktusai zavaróvá válnak, érdemes lehet a
tengely-logikát **egy helyre** kivezetni (pl. egy `BarLayout` singleton
`isVertical` + származtatott property-kkel), és a komponensekben csak erre
hivatkozni. Ez egyszeri, nagyobb refaktor, de utána az upstream merge-ek
jóval simábbak lennének. Jelenleg ez **nincs** megvalósítva.

---

## Elhagyott branchek

A régi mentő-branchek a `refs/backup/archive/` névtérbe kerültek — mind
tartalmazott olyan commitokat, amik a `main`-ben nincsenek meg
(a videó wallpaper javítások részletes története).

```bash
shell-sync-upstream --list                    # mindet listázza
git branch <új-név> refs/backup/archive/<név> # visszahozás branchként
```

| Archív ref | Egyedi commitok | Mi ez |
|---|---|---|
| `archive/main-backup-with-fixes` | 11 | a videó wallpaper részletes javítási története |
| `archive/my-backup-before-update` | 10 | a fork régi vonala (= az elavult `origin/main`) |
| `archive/base-with-video-fix` | 1 | a videó támogatás átportolása frissebb upstreamre |
| `archive/main-working-video-upstream` | 0 | régebbi pont ugyanezen a vonalon |

A `main` az egyetlen élő fejlesztési vonal.
