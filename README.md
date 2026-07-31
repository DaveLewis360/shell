<h1 align=center>caelestia-shell — horizontal fork</h1>

<div align=center>

A fork of [`caelestia-dots/shell`](https://github.com/caelestia-dots/shell)
that brings back the **horizontal bar** — switchable at runtime, without
restarting the shell.

![GitHub last commit](https://img.shields.io/github/last-commit/DaveLewis360/shell?style=for-the-badge&labelColor=101418&color=9ccbfb)
![GitHub repo size](https://img.shields.io/github/repo-size/DaveLewis360/shell?style=for-the-badge&labelColor=101418&color=d3bfe6)
![License](https://img.shields.io/github/license/DaveLewis360/shell?style=for-the-badge&labelColor=101418&color=b9c8da)

</div>

> [!IMPORTANT]
> **This is a modified version of caelestia-shell, not the original.**
> Upstream is intentionally vertical-only — commit `63da6361`
> *"internal: bar only vertical"* removed horizontal support in May 2025.
> This fork restores it. All credit for the shell itself goes to
> [soramanew](https://github.com/soramanew) and the caelestia contributors.
> Licensed under GPL-3.0, same as upstream.

## Screenshots

<!-- SCREENSHOT-HORIZONTAL -->

<!-- SCREENSHOT-VERTICAL -->

## What this fork adds

| Feature | What it does |
| --- | --- |
| **Horizontal bar** | The bar runs along the top edge instead of the left. Both layouts ship side by side and you switch between them at runtime. |
| **MiniDash** | A compact dashboard that lives in the bar. |
| **Video wallpapers** | Upstream supports images only; this fork plays videos too. |
| **Clock with date** | Day name and day of month next to the time. |
| **Album art fallback** | Keeps the last known cover instead of blanking when a player reports no art. |

Everything else behaves exactly like upstream. If a feature is not in the table
above, the [upstream documentation](docs/UPSTREAM-README.md) applies unchanged.

## Install

Requires an existing working [Hyprland](https://hyprland.org) +
[Quickshell](https://quickshell.outfoxxed.me) setup, the same as upstream.

```bash
git clone https://github.com/DaveLewis360/shell.git
cd shell
./install.sh
```

The installer is non-destructive: it backs up anything it replaces and prints an
exact command to undo the install. It never overwrites your `shell.json` — new
keys are merged in, your existing settings are kept.

For the full dependency list and distro-specific notes, see the
[upstream install instructions](docs/UPSTREAM-README.md#installation) — they
apply to this fork as well.

## Switching the bar layout

Three ways, all equivalent — they write the same file:

**Settings app** — Panels → Taskbar → Layout → *Horizontal bar*

**Command line**

```bash
barmode              # show current layout
barmode toggle       # switch
barmode h            # horizontal (top edge)
barmode v            # vertical (left edge, upstream layout)
```

**Config file** — `~/.config/caelestia/extras.json`

```json
{
    "bar": { "horizontal": true }
}
```

The change applies in about a second. No restart, no relogin.

> [!NOTE]
> `barmode` ships with the [dotfiles repo](https://github.com/DaveLewis360/dotfiles).
> If you only installed the shell, use the settings app or edit the file
> directly.

## Configuration

This fork keeps its own settings in a **separate file** from upstream's:

```
~/.config/caelestia/shell.json     upstream settings (untouched)
~/.config/caelestia/extras.json    this fork's settings
```

| Key | Default | Meaning |
| --- | --- | --- |
| `bar.horizontal` | `false` | `true` = top edge, `false` = upstream's left edge |
| `miniDash.enabled` | `true` | Show the compact dashboard in the bar |

Both files are watched live — save and the change takes effect.

<details>
<summary>Why a separate file instead of adding keys to <code>shell.json</code>?</summary>

Upstream's C++ `ConfigObject` only exposes keys that exist in its schema as QML
properties. Unknown keys are *preserved* on save (since commit `6e570081`), but
they never become readable properties. So a fork cannot add settings to
`shell.json` without patching upstream's schema. A separate file costs nothing
and keeps the merge surface at zero.

</details>

## Staying in sync with upstream

This fork tracks upstream and is currently based on **`v2.2.0`**
(merge base `06b4fe07`).

```bash
fork-diff       # what this fork changes, grouped by conflict risk
fork-drift      # has upstream touched anything this fork copied?
```

Current divergence: **18 fork-only files** (zero conflict risk) and
**22 modified upstream files** across 151 hunks. The horizontal bar is the bulk
of it, and it is a permanent divergence rather than a temporary one — see
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the measurements behind that
statement, including why the horizontal bar cannot be implemented as a pure
add-on.

## Documentation

| Document | Contents |
| --- | --- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the fork is structured, what conflicts on merge, and why |
| [custom/README.md](custom/README.md) | The fork-only components |
| [docs/UPSTREAM-README.md](docs/UPSTREAM-README.md) | Upstream's original README, preserved verbatim — the full config reference lives here |

## Credits

The shell is the work of [soramanew](https://github.com/soramanew) and the
[caelestia](https://github.com/caelestia-dots) contributors. This fork only adds
a horizontal layout and a handful of personal touches on top of it.

If you like the shell, support the original author:
[Ko-Fi](https://ko-fi.com/soramane) ·
[Discord](https://discord.gg/BGDCFCmMBk)

## License

GPL-3.0, inherited from upstream. See [LICENSE](LICENSE).

In accordance with GPL-3.0 section 5(a): this is a modified version of
`caelestia-dots/shell`. Modifications began in 2025 and are ongoing; the
complete list of changes is available through `fork-diff` and in the git
history.
