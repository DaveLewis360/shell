# DaveLewis360/shell

[caelestia-dots/shell](https://github.com/caelestia-dots/shell) with one addition:
the bar can sit along the top edge instead of the left, plus a few small
[fixes](#fixes). Everything else is the upstream release, unchanged. For the shell
itself, its features and its configuration, see the [upstream README](../README.md).

## The bar toggle

Nexus → Panels → Taskbar → Position → "Horizontal bar", or in `shell.json`:

```json
"fork": {
    "bar": { "horizontal": true }
}
```

The shell switches live. Off, the bar is upstream's, pixel for pixel. On, the
bar is the same bar laid out as a row: the same `bar.entries`, the same options,
icons, fonts and colours. Popouts hang below it; the dashboard opens from the
top edge, over the bar.

## How the fork is kept

- Releases are tagged `v<upstream>.<n>`, e.g. `v2.5.0.1` is upstream v2.5.0 plus
  the fork's patches.
- Each fork commit is one step, `fork(<area>): ...`, rebased onto every upstream
  release. `main` is rewritten when that happens.
- Fork code lives in [`custom/`](../custom/README.md). Upstream files only get
  small hooks marked `[fork]`.
- `scripts/fork-sandbox` runs a checkout in a nested Hyprland with its own config,
  state and D-Bus session, reports QML errors and takes a screenshot.

Bugs in the top bar or in the fixes below go to this repository. Everything else
is upstream's.

## Fixes

Small fixes for things upstream does not handle yet, each its own commit:

- **Num Lock indicator**: `fork.bar.showNumLock: false` (Nexus → Panels →
  Taskbar → Status icons → Lock keys) hides the Num Lock icon, for keyboards
  that keep Num Lock on. Caps Lock still shows.
- **Cover art**: covers keep the last art that loaded instead of blinking out
  between tracks. Local art files are copied into `~/.cache/caelestia/covers`,
  so a browser deleting them (Firefox-based browsers and their web apps wipe each
  other's) no longer breaks the cover (`custom/media/CoverArtCache`).

## Licence

GPL-3.0, like upstream. See [LICENSE](../LICENSE).
