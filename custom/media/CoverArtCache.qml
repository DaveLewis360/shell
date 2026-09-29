pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.services
import qs.utils

// The cover art the shell shows, in place of Players.getArtUrl(Players.active).
//
// Covers blink out or break when the player's art does:
// - Browsers (Firefox, Zen, and web apps built on them) clear the art URL for a
//   moment on every track change.
// - A local art file is often temporary. Firefox-based browsers keep it in one
//   `firefox-mpris` folder per profile root and wipe that folder whenever their art
//   changes, so two instances (a browser and a web app) delete each other's covers.
//   The file can also be written only after its URL was announced.
// Upstream shows the URL as is, so the cover drops to the placeholder between
// tracks, and stays broken once its file is gone.
//
// This copies each player's local art file into the shell's cache as soon as it
// appears, so it survives the browser deleting it. For the active player it retries
// for a few seconds while the file is not there yet, loads the new art in the
// background, and switches the covers only once it has loaded. Until then they keep
// the last art that loaded; with no player they clear.
Singleton {
    id: root

    // The active player's art, as upstream reads it
    readonly property string current: Players.getArtUrl(Players.active)
    readonly property bool hasPlayer: !!Players.active

    // What covers should show
    property string url

    readonly property string dir: `${Paths.cache}/covers`
    readonly property int keptCopies: 30
    readonly property int maxRetries: 10
    property int retries

    // The art URL the background load is for
    property string loadingFor

    function update(): void {
        retryTimer.stop();
        retries = 0;
        if (!hasPlayer)
            url = "";
        fetch();
    }

    function fetch(): void {
        if (copyProc.running) {
            copyProc.queued = true;
            return;
        }

        loadingFor = current;
        probe.source = "";

        if (!current)
            return; // Keep the last cover while the player has none

        if (!current.startsWith("file:")) {
            probe.source = current;
            return;
        }

        copyProc.dst = copyPath(current);
        copyProc.command = copyCommand(current);
        copyProc.running = true;
    }

    // Where the cache keeps its copy of a local art file
    function copyPath(art: string): string {
        const src = Paths.toLocalFile(art);
        const ext = src.match(/\.([A-Za-z0-9]{1,5})$/)?.[1] ?? "img";
        return `${dir}/${Qt.md5(src)}.${ext}`;
    }

    function copyCommand(art: string): list<string> {
        return ["sh", "-c", copyProc.script, "sh", dir, Paths.toLocalFile(art), copyPath(art), keptCopies];
    }

    function retryOrGiveUp(): void {
        if (retries < maxRetries)
            retryTimer.restart();
        else
            url = current; // Gone for good, show it failing like upstream
    }

    onCurrentChanged: update()
    onHasPlayerChanged: update()
    Component.onCompleted: update()

    Process {
        id: copyProc

        // Copies the art $2 to $3 in the private folder $1, and keeps the $4 newest
        // copies. Once $2 is gone, an earlier copy of it still counts. Only regular
        // files up to 20 MiB are copied.
        readonly property string script: `
            umask 077
            mkdir -p -- "$1" || exit 1
            if [ -f "$2" ] && [ "$(stat -c %s -- "$2")" -le 20971520 ]; then
                cp -f -- "$2" "$3.$$.tmp" && mv -f -- "$3.$$.tmp" "$3" || exit 1
            elif [ -f "$3" ]; then
                touch -- "$3"
            else
                exit 1
            fi
            cd -- "$1" && ls -1t | tail -n +$(($4 + 1)) | while IFS= read -r f; do rm -f -- "$f"; done
            exit 0`

        property string dst
        property bool queued

        onExited: code => { // qmllint disable signal-handler-parameters
            if (queued) {
                queued = false;
                Qt.callLater(root.fetch);
                return;
            }
            if (root.loadingFor !== root.current)
                return;

            if (code === 0)
                probe.source = Qt.resolvedUrl(`file://${dst}`);
            else
                root.retryOrGiveUp();
        }
    }

    Image {
        id: probe

        asynchronous: true
        cache: false
        sourceSize: Qt.size(64, 64)

        onStatusChanged: {
            if (root.loadingFor !== root.current || !source.toString())
                return;

            if (status === Image.Ready) {
                root.url = source.toString();
            } else if (status === Image.Error) {
                if (root.current.startsWith("file:"))
                    root.retryOrGiveUp();
                else
                    root.url = root.current;
            }
        }
    }

    // Copy every player's local art as soon as it appears, not only the active
    // one's: switching players later still finds its cover after a browser has
    // wiped the file.
    Variants {
        model: Players.list

        QtObject {
            required property MprisPlayer modelData
            readonly property string art: Players.getArtUrl(modelData)

            function backup(): void {
                if (art.startsWith("file:") && modelData !== Players.active)
                    Quickshell.execDetached(root.copyCommand(art));
            }

            onArtChanged: backup()
            Component.onCompleted: backup()
        }
    }

    Timer {
        id: retryTimer

        interval: 500
        onTriggered: {
            root.retries++;
            root.fetch();
        }
    }
}
