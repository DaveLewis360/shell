# Contributing

## First: should it go upstream instead?

This fork exists for one reason — upstream is
[deliberately vertical-only](../docs/ARCHITECTURE.md#the-one-structural-fact-that-shapes-everything).
Everything else here is upstream code.

So before opening a PR, ask whether the change belongs at
[caelestia-dots/shell](https://github.com/caelestia-dots/shell). If it does,
send it there — everyone benefits, and this fork stays small enough to keep
merging cleanly. Anything accepted upstream gets deleted from here.

Changes that clearly belong in this fork:

- the horizontal bar and its components (`custom/bar/`)
- orientation handling in `modules/drawers/`
- the fork's own components (`custom/`)

## Keeping the merge surface small

The single most important rule: **do not modify an upstream file if you can
avoid it.** Every modified upstream file is a future merge conflict.

In order of preference:

1. Add a new file under `custom/` — zero conflict risk
2. Add a setting to `extras.json` via `custom/ExtrasConfig.qml`
3. Only then, modify an upstream file

Check what you added:

```bash
fork-diff           # summary by conflict risk
fork-diff --files   # per-file breakdown
```

## If you touch orientation logic

Use explicit `x`/`y`/`width`/`height`. **Not** conditional anchors:

```qml
anchors.bottom: cond ? parent.bottom : undefined   // does NOT clear the anchor
```

The anchor stays live and the item stretches to both edges. This has already
caused one visible regression.

## If you copy a file from upstream

Copies under `custom/bar/` go stale silently when upstream fixes the original.
Record the provenance in `custom/bar/VENDORED.json` — upstream path, blob hash
and ref — otherwise `fork-drift` cannot detect drift for that file.

```bash
fork-drift          # verify it is picked up
```

## Code style

Same as upstream:

- commit messages: `module: change`
- no trailing whitespace, single space between operators
- format QML with the VS Code QML extension defaults, or just match the
  surrounding code

## Test it

Both layouts, not just the one you use:

```bash
barmode h    # horizontal
barmode v    # vertical — must still behave exactly like upstream
```

Then check the log is clean:

```bash
qs log /run/user/$UID/quickshell/by-pid/$(pgrep -x qs)/log.qslog | grep -i error
```

State in the PR description which layouts you tested. "Works on my machine in
horizontal mode" is a fine thing to say — silently breaking the vertical layout
is not.
