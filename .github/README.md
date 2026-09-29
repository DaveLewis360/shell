# DaveLewis360/shell

[caelestia-dots/shell](https://github.com/caelestia-dots/shell) with one addition:
the bar can sit along the top edge instead of the left. Everything else is the
upstream release, unchanged. For the shell itself, its features and its
configuration, see the [upstream README](../README.md).

## The bar toggle

Nexus → Panels → Taskbar → Position → "Horizontal bar", or in `shell.json`:

```json
"fork": {
    "bar": { "horizontal": true }
}
```

The shell switches live. Off, the shell is upstream's, pixel for pixel. On, the
bar is the same bar laid out as a row: the same `bar.entries`, the same options,
icons, fonts and colours. Popouts and the dashboard hang below it.

## How the fork is kept

- Releases are tagged `v<upstream>.<n>`, e.g. `v2.5.0.1` is upstream v2.5.0 plus
  the fork's patches.
- Each fork commit is one step, `fork(<area>): ...`, rebased onto every upstream
  release. `main` is rewritten when that happens.
- Fork code lives in [`custom/`](../custom/README.md). Upstream files only get
  small hooks marked `[fork]`.
- `scripts/fork-sandbox` runs a checkout in a nested Hyprland with its own config,
  state and D-Bus session, reports QML errors and takes a screenshot.

Bugs in the top bar go to this repository. Everything else is upstream's.

## Licence

GPL-3.0, like upstream. See [LICENSE](../LICENSE).
