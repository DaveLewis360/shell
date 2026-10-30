pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils
import qs.custom.wallpaper as Fork // [fork]

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    // [fork] Video wallpapers (custom/wallpaper): the background plays `currentVideo`,
    // and everything that needs an image gets its poster frame through `current`
    readonly property string shown: showPreview ? previewPath : actualCurrent
    readonly property string current: Fork.VideoWallpapers.still(shown)
    readonly property string currentVideo: Fork.VideoWallpapers.isVideo(shown) ? shown : ""
    property string previewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        actualCurrent = path;
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
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
    onCurrentVideoChanged: Fork.VideoWallpapers.request(currentVideo, true) // [fork] its poster first

    // [fork] Videos sort in among the images, as in a single model
    list: Array.from(wallpapers.entries).concat(Array.from(Fork.VideoWallpapers.entries)).sort((a, b) => a.relativePath.localeCompare(b.relativePath))
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
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
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

    Process {
        id: getPreviewColoursProc

        // [fork] The wallpaper this run is for. A run whose preview has moved on or
        // ended is not applied, and the newest preview is run again.
        property string ranFor
        readonly property bool wanted: root.showPreview || root.previewColourLock

        command: ["caelestia", "wallpaper", "-p", Fork.VideoWallpapers.colourSource(root.previewPath), ...root.smartArg] // [fork] a video's poster
        stdout: StdioCollector {
            onStreamFinished: {
                if (!getPreviewColoursProc.wanted || getPreviewColoursProc.ranFor !== root.previewPath) // [fork]
                    return;
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
        onStarted: ranFor = root.previewPath // [fork]
        onExited: {
            // [fork]
            if (wanted && ranFor !== root.previewPath && Colours.scheme === "dynamic")
                Qt.callLater(() => getPreviewColoursProc.running = true);
        }
    }
}
