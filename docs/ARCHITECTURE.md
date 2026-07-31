# Architecture

How this fork is organised, what it costs to maintain, and why it is built the
way it is.

Base: **`v2.2.0`** (merge base `06b4fe07`)

Run `fork-diff` for live numbers — the figures below can go stale.

---

## The one structural fact that shapes everything

**Upstream is deliberately vertical-only.**

Commit `63da6361` *"internal: bar only vertical"* (2025-05-27, still in `main`)
removed horizontal bar support and deleted the orientation-agnostic `Box`,
`BoxLayout` and `AnchorText` widgets along with it. There is no bar orientation
option in the current `shell.json` schema.

This fork brings the horizontal bar back. That makes it a **permanent
divergence**, not a temporary patch waiting to be upstreamed — and it lives in
exactly the files upstream keeps polishing.

---

## Why the horizontal bar cannot be a plain add-on

This was measured, not assumed.

**Layout type cannot be swapped by binding.** An isolated Quickshell test:

| Approach | Result |
| --- | --- |
| `GridLayout { flow: vertical ? TopToBottom : LeftToRight }` | **does not reflow** — `40x45` → `40x45`, children stay put |
| `Loader { sourceComponent: vertical ? colComp : rowComp }` | **works** — `40x45` → `85x20` |

So `ColumnLayout` → `RowLayout` requires *rebuilding* the layout. An external
add-on cannot change the type of an existing layout at all.

**The axis logic is spread across the whole bar tree** — 129 axis-sensitive
lines in 12 files (`SpecialWorkspaces` 23, `StatusIcons` 18, `Tray` 17,
`Clock` 16, `ActiveWindow` 13, `Bar` 11, `BarWrapper` 8, workspace components
19, `Power` 4).

Conclusion: a horizontal bar needs either upstream support or a fork. It cannot
be a drop-in extension.

**What *can* be an add-on:** upstream `6e570081` preserves unknown config keys
on save (verified live), and `04cb43ff` added component lookup
(`ShellState.componentsFor(screen).find("taskbarClock", bar)`) plus
`objectName`s on every bar entry. So new widgets that only *read* upstream
components are genuinely add-on territory — which is where `custom/MiniDash.qml`
sits.

---

## How the two layouts coexist

`modules/bar/BarWrapper.qml` holds a `Loader` that picks one of two components:

```
ExtrasConfig.horizontalBar == true   →  custom/bar/HBar.qml      (fork)
ExtrasConfig.horizontalBar == false  →  modules/bar/Bar.qml      (pristine upstream)
```

Because `Loader` rebuilds the component, the switch works at runtime. The
upstream vertical bar and its components are **byte-identical to upstream** —
verify with `git diff 06b4fe07 -- modules/bar/Bar.qml`.

### Two mechanisms, deliberately different

| Layer | Mechanism | Why |
| --- | --- | --- |
| The bar itself (`custom/bar/H*.qml`) | **Copies** of upstream files | Axis swaps rewrite the *internal* layout of components, which cannot be overridden from outside. Copying keeps `modules/bar/` pristine. |
| The layer around it (`modules/drawers/*`) | **Conditionals** in upstream files | Space reservation and hover zones live in files that are referenced by `required property` across four other files. Copying them would mean rewiring all of it. |

Both have a cost, and they are opposite costs:

- **Copies drift silently.** If upstream fixes a bug in `Bar.qml`, the copy in
  `custom/bar/HBar.qml` never gets it, and nothing warns you. Mitigation:
  `custom/bar/VENDORED.json` records the upstream blob hash of every copy, and
  `fork-drift` compares them against current upstream.
- **Conditionals produce merge conflicts.** That is noisy but *visible* —
  a conflict is information, not a failure.

### The `undefined` anchor trap

Every orientation conditional in this fork uses explicit `x`/`y`/`width`/`height`
rather than conditional anchors, because in QML:

```qml
anchors.bottom: cond ? parent.bottom : undefined   // does NOT clear the anchor
```

The anchor stays live, the item stretches to both edges, and the content ends up
centred instead of on the edge. This bit the bar wrapper once already. If you add
orientation logic, do not use anchors for it.

---

## Where the fork's changes live

| Group | Files | Conflict risk | Notes |
| --- | --- | --- | --- |
| Fork-only files | 17 | **none** | `custom/` — upstream does not know they exist |
| Horizontal bar plumbing | 9 | **high** | Axis-sensitive lines in files upstream actively edits |
| Video wallpaper | 4 | medium | Upstream is developing `nexus`, so `WallItem.qml` may get worse |
| Own features | 4 | low | Well-isolated additions |
| Small visual tweaks | 6 | low | |

### Merge tactic for the high-risk group

When upstream edits the same line, the correct result is almost always
**your geometry + upstream's logic change**. Take their substantive change, keep
the axis swap. `rerere` remembers each such decision after the first time.

Enabled in this repo:

- **`rerere`** — records conflict resolutions and replays them automatically
- **`merge.conflictStyle=zdiff3`** — shows the common ancestor, so you can see
  what upstream actually changed
- **`diff.algorithm=histogram`** — fewer false conflicts in QML

---

## Syncing with upstream

```bash
shell-sync-upstream                 # merge upstream/main
shell-sync-upstream --tag v2.2.0    # merge a specific tag
shell-sync-upstream --abort         # drop an in-progress merge
shell-sync-upstream --undo          # undo a COMPLETED merge
```

Every run creates a restore point under `refs/backup/pre-merge/<timestamp>`
first, so any merge is one command away from being undone.

```bash
git reset --hard refs/backup/<name>
```

> **Why refs, not tags?** `CMakeLists.txt` derives the version from
> `git describe --tags --abbrev=0`. A custom tag would shadow the `v2.x.y`
> version tags and break the build with
> `VERSION "restore-point/..." format invalid`. Refs under `refs/backup/` are
> invisible to `git describe` but work fine with `reset`, `log` and `branch`.

### Detecting silent drift

```bash
fork-drift              # check the vendored copies against upstream
fork-drift --show <f>   # what changed upstream in one copied file
```

Exit code is `1` when drift is found, so it can run from a timer.

---

## Upstreaming, in order of value

Anything accepted upstream can be deleted from this fork permanently.

| # | Change | Size | Frees up |
| --- | --- | --- | --- |
| 1 | `objectName` on the wallpaper `Loader` (`Background.qml:42`) | 1 line | Makes video wallpaper replaceable from outside |
| 2 | `bar.workspaces.background` bool | 1 line | 1 line here — the `tray`/`clock` sections already have this key |
| 3 | Album art fallback (`Players.lastArtUrl`) | 27 lines | 27 lines, and it is an objective bug fix |
| 4 | **Bar orientation option** | ~129 lines upstream | The entire horizontal bar divergence |

Sketch for #4, supported by the measurement above: move the `Bar.qml` layout
into a `Loader` with two components (`ColumnLayout` / `RowLayout`), and have
child entries read a `readonly property bool vertical: Config.bar.vertical`. The
`Loader` route is proven to work.

Counter-argument to know going in: `63da6361` removed horizontal support
**on purpose**. So open an issue before writing code.

---

## Archived branches

Old backup branches live under `refs/backup/archive/`. Each held commits absent
from `main` (mostly the detailed history of the video wallpaper work).

```bash
shell-sync-upstream --list                     # list everything
git branch <new-name> refs/backup/archive/<name>   # bring one back
```

`main` is the only live line of development.
