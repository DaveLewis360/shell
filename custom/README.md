# `custom/` — fork-only components

Everything here exists **only in this fork**. None of it is a modification of an
upstream file, so none of it can ever conflict during an upstream merge —
upstream does not know these files exist.

## Contents

| File | What it is |
| --- | --- |
| `ExtrasConfig.qml` | Reads this fork's settings from `~/.config/caelestia/extras.json` |
| `MiniDash.qml` | Compact dashboard that lives in the bar |
| `bar/H*.qml` | The horizontal bar and its components — copies of upstream's `modules/bar/` files with the axes swapped. Provenance recorded in `bar/VENDORED.json` |

## Importing

Quickshell exposes the shell root as the `qs` namespace:

```qml
import qs.custom

MiniDash { }
```

## Convention

- **Belongs here:** a component that does not exist upstream at all.
- **Does not belong here:** a modification of an upstream component. Edit that in
  place — see [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) for why.

## The catch with `bar/` copies

The horizontal bar is a `Column`→`Row` / `y`↔`x` transformation of upstream
components' *internal* layout. That cannot be overridden from outside, so the
files had to be copied.

The upside: `modules/bar/` stays byte-identical to upstream, so merges there are
clean. The downside: these copies **go stale silently** when upstream fixes
something in the original.

That is what `fork-drift` is for:

```bash
fork-drift              # are any copies out of date?
fork-drift --show HBar.qml   # what changed upstream
```

`VENDORED.json` records the upstream path, blob hash and ref for each copy, which
is what makes the comparison possible. **If you re-sync a copy from upstream,
update its entry** — otherwise drift detection silently stops working for that
file.

## Settings

`ExtrasConfig` reads `~/.config/caelestia/extras.json`:

```json
{
    "bar": { "horizontal": true },
    "miniDash": { "enabled": true }
}
```

Two implementation details worth knowing if you touch it:

**It reads through a binding, not `onLoaded`.** `FileView.blockLoading` only
blocks if `text()` is actually called, so the value must come from a binding. Read
it in `onLoaded` instead and the shell builds its first frame with the *wrong*
default — the bar renders vertical, then jumps to horizontal, and the Wayland
exclusive zone ends up reserved on both edges at once.

**Writes go through `setValue()`**, which rewrites the whole file. The `data`
binding then re-evaluates from the file change, so there is no manual state to
keep in sync.
