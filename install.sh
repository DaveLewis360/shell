#!/usr/bin/env bash
# =============================================================================
#  caelestia-shell (horizontal fork) — installer
# =============================================================================
#  Usage:
#    ./install.sh              install
#    ./install.sh --check      check dependencies only, change nothing
#    ./install.sh --uninstall  remove and restore whatever was replaced
#    ./install.sh --yes        skip the confirmation prompt
#
#  Nothing is deleted. Anything replaced is moved to a timestamped backup and
#  the exact undo command is printed at the end.
#
#  Your ~/.config/caelestia/shell.json is never touched. This fork keeps its own
#  settings in a separate extras.json.
# =============================================================================

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
QS_CONF_DIR="$XDG_CONFIG/quickshell/caelestia"
CAELESTIA_CONF="$XDG_CONFIG/caelestia"
EXTRAS_JSON="$CAELESTIA_CONF/extras.json"
BACKUP_ROOT="$XDG_CONFIG/caelestia-fork-backups"
STAMP="$(date +%Y%m%d_%H%M%S)"

MODE="install"
ASSUME_YES=0

for arg in "$@"; do
    case "$arg" in
        --check)     MODE="check" ;;
        --uninstall) MODE="uninstall" ;;
        --yes|-y)    ASSUME_YES=1 ;;
        -h|--help)   sed -n '3,15p' "$0" | sed 's/^# \?//' | grep -v '^=\+$'; exit 0 ;;
        *)           echo "Unknown option: $arg" >&2; exit 2 ;;
    esac
done

# ── output helpers ───────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    B=$'\033[1m'; D=$'\033[2m'; R=$'\033[0m'
    GRN=$'\033[32m'; YLW=$'\033[33m'; RED=$'\033[31m'; CYN=$'\033[36m'
else
    B=""; D=""; R=""; GRN=""; YLW=""; RED=""; CYN=""
fi

ok()   { echo "  ${GRN}✓${R} $*"; }
warn() { echo "  ${YLW}!${R} $*"; }
err()  { echo "  ${RED}✗${R} $*" >&2; }
step() { echo; echo "${B}$*${R}"; }
info() { echo "  ${D}$*${R}"; }

die() { err "$*"; exit 1; }

# ── dependency check ─────────────────────────────────────────────────────────
BUILD_DEPS=(cmake ninja git)
RUNTIME_CMDS=(qs hyprctl)
# Runtime libraries/tools the shell expects. Package names differ per distro, so
# these are reported, never installed automatically.
RUNTIME_OPTIONAL=(ddcutil brightnessctl fish swappy qalc)

check_deps() {
    local missing_build=() missing_run=() missing_opt=()

    for c in "${BUILD_DEPS[@]}"; do
        command -v "$c" >/dev/null 2>&1 || missing_build+=("$c")
    done
    for c in "${RUNTIME_CMDS[@]}"; do
        command -v "$c" >/dev/null 2>&1 || missing_run+=("$c")
    done
    for c in "${RUNTIME_OPTIONAL[@]}"; do
        command -v "$c" >/dev/null 2>&1 || missing_opt+=("$c")
    done

    if [[ ${#missing_build[@]} -eq 0 ]]; then
        ok "build tools: ${BUILD_DEPS[*]}"
    else
        err "missing build tools: ${missing_build[*]}"
    fi

    if [[ ${#missing_run[@]} -eq 0 ]]; then
        ok "runtime: ${RUNTIME_CMDS[*]}"
    else
        err "missing: ${missing_run[*]}"
        info "quickshell must be the git version (quickshell-git), not the latest tag"
    fi

    if [[ ${#missing_opt[@]} -gt 0 ]]; then
        warn "optional tools not found: ${missing_opt[*]}"
        info "the shell runs without them, but some features will be inactive"
    fi

    # Upstream's full dependency list lives in docs/UPSTREAM-README.md
    if [[ ${#missing_build[@]} -gt 0 || ${#missing_run[@]} -gt 0 ]]; then
        echo
        info "full dependency list: docs/UPSTREAM-README.md"
        return 1
    fi
    return 0
}

# ── version resolution ───────────────────────────────────────────────────────
# CMakeLists derives VERSION from `git describe --tags`, which fails outright if
# the clone has no tags (shallow clone, or tags never pushed). Resolve it here
# and pass it explicitly so the build cannot fail for that reason.
resolve_version() {
    local v
    v="$(git -C "$REPO_DIR" describe --tags --abbrev=0 2>/dev/null)"
    if [[ -n "$v" ]]; then
        echo "$v"
        return
    fi
    if [[ -f "$REPO_DIR/VERSION" ]]; then
        tr -d '[:space:]' < "$REPO_DIR/VERSION"
        return
    fi
    echo "0.0.0"
}

# ── uninstall ────────────────────────────────────────────────────────────────
do_uninstall() {
    step "Uninstalling"

    local manifest="$REPO_DIR/build/install_manifest.txt"
    if [[ -f "$manifest" ]]; then
        local n
        n=$(wc -l < "$manifest")
        info "removing $n installed files (sudo required)"
        # shellcheck disable=SC2024
        sudo xargs -a "$manifest" rm -f 2>/dev/null
        ok "installed files removed"
    else
        warn "no build/install_manifest.txt — nothing to remove"
        info "if you installed from a different checkout, run --uninstall there"
    fi

    local latest
    latest=$(find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'qs-config_*' 2>/dev/null | sort | tail -1)
    if [[ -n "$latest" ]]; then
        echo
        info "a backup of your previous Quickshell config exists:"
        info "  $latest"
        info "restore it with:"
        echo "    rm -rf '$QS_CONF_DIR' && mv '$latest' '$QS_CONF_DIR'"
    fi

    echo
    ok "done"
    info "your settings in $CAELESTIA_CONF were left untouched"
}

# ── main ─────────────────────────────────────────────────────────────────────
echo
echo "${B}caelestia-shell — horizontal fork${R}"
echo "${D}$REPO_DIR${R}"

case "$MODE" in
    check)
        step "Dependencies"
        check_deps && { echo; ok "all good"; exit 0; } || exit 1
        ;;
    uninstall)
        do_uninstall
        exit 0
        ;;
esac

step "Dependencies"
check_deps || die "install the missing dependencies first, then run this again"

VERSION="$(resolve_version)"

step "Plan"
echo "  version      ${CYN}${VERSION}${R}"
echo "  build in     $REPO_DIR/build"
echo "  install to   $QS_CONF_DIR   ${D}(Quickshell config)${R}"
echo "               system paths for the QML plugin and beat detector ${D}(needs sudo)${R}"
echo "  settings     $EXTRAS_JSON   ${D}(created if missing)${R}"
echo
echo "  ${D}shell.json is never modified. Replaced files are backed up to${R}"
echo "  ${D}$BACKUP_ROOT${R}"

if [[ $ASSUME_YES -eq 0 ]]; then
    echo
    read -r -p "  Proceed? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { echo; info "aborted, nothing changed"; exit 0; }
fi

# ── build ────────────────────────────────────────────────────────────────────
step "Building"
cmake -B "$REPO_DIR/build" -S "$REPO_DIR" -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/ \
      -DVERSION="$VERSION" \
      -DINSTALL_QSCONFDIR="$QS_CONF_DIR" >/dev/null \
    || die "cmake configure failed"
ok "configured"

cmake --build "$REPO_DIR/build" || die "build failed"
ok "built"

# ── back up an existing config dir ───────────────────────────────────────────
if [[ -e "$QS_CONF_DIR" || -L "$QS_CONF_DIR" ]]; then
    real_target="$(readlink -f "$QS_CONF_DIR" 2>/dev/null || echo "$QS_CONF_DIR")"
    if [[ "$real_target" == "$REPO_DIR" ]]; then
        info "$QS_CONF_DIR already points at this repo — leaving it alone"
    else
        mkdir -p "$BACKUP_ROOT"
        backup="$BACKUP_ROOT/qs-config_$STAMP"
        mv "$QS_CONF_DIR" "$backup" || die "could not back up $QS_CONF_DIR"
        ok "existing config backed up to $backup"
        RESTORE_CMD="rm -rf '$QS_CONF_DIR' && mv '$backup' '$QS_CONF_DIR'"
    fi
fi

# ── install ──────────────────────────────────────────────────────────────────
step "Installing"
info "sudo is needed to install the QML plugin and the beat detector"
sudo cmake --install "$REPO_DIR/build" >/dev/null || die "install failed"
# cmake --install runs as root, so the config dir ends up root-owned
[[ -d "$QS_CONF_DIR" ]] && sudo chown -R "$USER" "$QS_CONF_DIR"
ok "installed"

# ── settings ─────────────────────────────────────────────────────────────────
step "Settings"
mkdir -p "$CAELESTIA_CONF"

if [[ -f "$EXTRAS_JSON" ]]; then
    # Merge defaults into the existing file without clobbering anything the user
    # already set. Their values always win.
    python3 - "$EXTRAS_JSON" <<'PY'
import json, sys

path = sys.argv[1]
defaults = {"bar": {"horizontal": True}, "miniDash": {"enabled": True}}

try:
    with open(path) as f:
        current = json.load(f)
except Exception as e:
    print(f"  ! {path} is not valid JSON ({e}) — leaving it untouched")
    sys.exit(0)

added = []
for section, values in defaults.items():
    if not isinstance(current.get(section), dict):
        current[section] = {}
    for key, value in values.items():
        if key not in current[section]:
            current[section][key] = value
            added.append(f"{section}.{key}")

if added:
    with open(path, "w") as f:
        json.dump(current, f, indent=4)
        f.write("\n")
    print("  added missing keys: " + ", ".join(added))
else:
    print("  already up to date, nothing changed")
PY
    ok "$EXTRAS_JSON"
else
    cat > "$EXTRAS_JSON" <<'EOF'
{
    "bar": {
        "horizontal": true
    },
    "miniDash": {
        "enabled": true
    }
}
EOF
    ok "created $EXTRAS_JSON"
fi

if [[ ! -f "$CAELESTIA_CONF/shell.json" ]]; then
    info "no shell.json yet — the shell will create one with its defaults"
else
    info "shell.json left untouched, as promised"
fi

# ── done ─────────────────────────────────────────────────────────────────────
step "Done"
echo "  Start the shell:"
echo "    ${CYN}qs -c caelestia${R}"
echo
echo "  Switch the bar layout:"
echo "    edit ${CYN}$EXTRAS_JSON${R} → ${CYN}bar.horizontal${R}"
echo "    or use the settings app: ${D}Panels → Taskbar → Layout${R}"
echo "    ${D}(the change applies in about a second, no restart needed)${R}"
echo
echo "  Undo everything:"
echo "    ${CYN}./install.sh --uninstall${R}"
if [[ -n "${RESTORE_CMD:-}" ]]; then
    echo
    echo "  Restore your previous Quickshell config:"
    echo "    ${D}$RESTORE_CMD${R}"
fi
echo
