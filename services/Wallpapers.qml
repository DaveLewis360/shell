pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    readonly property bool currentIsVideo: Images.isVideoByName(actualCurrent)

    // Stable, content-addressed thumbnail cache (shared by launcher, control center & colour analysis)
    readonly property string thumbsDir: `${Paths.cache}/wallpaper/thumbnails`
    function thumbFor(path: string): string {
        return `${thumbsDir}/${Qt.md5(path)}.jpg`;
    }

    // Source the colour scheme/luminance reads from (video -> its poster frame)
    readonly property string currentColourSource: currentIsVideo ? thumbFor(actualCurrent) : actualCurrent

    function setWallpaper(path: string): void {
        actualCurrent = path;

        if (Images.isVideoByName(path)) {
            // Generate poster frame (lazily) + derive scheme from it; persist the *video* path.
            const thumb = thumbFor(path);
            Quickshell.execDetached(["bash", "-c", `mkdir -p '${thumbsDir}'; [ -f '${thumb}' ] || ffmpeg -y -i '${path}' -vframes 1 -q:v 2 '${thumb}'; caelestia wallpaper -f '${thumb}' ${smartArg.join(" ")}; echo -n '${path}' > '${currentNamePath}'`]);
        } else {
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
        }
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const savedPath = text().trim();
            if (!savedPath || savedPath.startsWith("/tmp/"))
                return;
            root.actualCurrent = savedPath;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

    // Native VideoOutput renders video now; clean up any leftover mpvpaper from the old approach.
    Component.onCompleted: Quickshell.execDetached(["pkill", "mpvpaper"])

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", Images.isVideoByName(root.previewPath) ? root.thumbFor(root.previewPath) : root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
