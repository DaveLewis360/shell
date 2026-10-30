pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Models
import qs.utils

// Video wallpapers.
//
// The caelestia CLI sets a video like an image: it saves the video's own path and
// takes the colour scheme from its first frame. The shell side lives here. The
// background plays the video (VideoLayer); everything that needs an image (the image
// layer under the video, the lock screen, the pickers, the luminance analyser) gets a
// poster frame through still().
//
// Posters are made with ffmpeg in the background, one at a time and at the lowest
// priority, scaled down, cached by path hash and written atomically. still() returns a
// poster only once the file exists, and the posters model is watched, so a binding
// that calls still() reloads by itself when the poster appears.
//
// The background never plays the original file. It plays a copy made for the screen
// (video-native.sh: H.264 that just covers nativeWidth x nativeHeight, at most
// nativeFps), which the same queue makes after the posters. Most originals are 4K, so
// the copy costs the decoder about a quarter as much. Until the copy exists, or if it
// cannot be played, the background shows the poster.
Singleton {
    id: root

    // Behaviour switches
    // Pause the video while a fullscreen window covers its monitor
    readonly property bool pauseWhenFullscreen: true
    // Pause the video while the laptop runs on battery
    readonly property bool pauseOnBattery: true
    // Stop the player instead of pausing it. That frees its memory and the decoder, and
    // the video starts again from its poster when it resumes.
    readonly property bool unloadWhenPaused: true
    // Off when the shell was started with CAELESTIA_VIDEO_WALLPAPER=0 (shell-restart
    // does that after repeated crashes): the posters show, nothing plays
    readonly property bool playVideos: Quickshell.env("CAELESTIA_VIDEO_WALLPAPER") !== "0"
    // The size the played copy just covers, and its frame rate cap
    readonly property int nativeWidth: 1920
    readonly property int nativeHeight: 1200
    readonly property int nativeFps: 30
    // How long the launcher has to rest on a video before the background plays it (ms).
    // Its poster shows at once either way.
    readonly property int previewDelay: 300

    // The video types of the caelestia CLI (VIDEO_EXTENSIONS) that Qt plays, so avi is left out
    readonly property list<string> extensions: ["mp4", "webm", "mkv", "mov"]
    readonly property string postersDir: `${Paths.cache}/wallpaper/video-posters`
    // Wider than any picker cell, enough for the blurred lock screen; the live video
    // covers the poster within a fraction of a second on the desktop
    readonly property int posterWidth: 1920
    readonly property string nativeDir: `${Paths.cache}/wallpaper/video-native`
    // Shown instead of a poster that cannot be made (a missing or broken video)
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")
    readonly property alias entries: videos.entries

    // Set by the lock screen ([fork] hook in modules/lock/Lock.qml): nothing of the
    // desktop shows while it is up, so the videos pause
    property bool sessionLocked

    // Paths of the posters on disk, rebuilt whenever the posters directory changes
    property var posters: new Set()
    // Videos waiting for a poster, the next one first
    property list<string> queue: []
    // Videos ffmpeg could not read, so they are not retried in this session
    property var failed: ({})
    // Paths of the played copies on disk, rebuilt whenever their directory changes
    property var natives: new Set()
    // Videos waiting for a played copy, the next one first
    property list<string> nativeQueue: []
    // Videos with no played copy (ffmpeg failed) and copies the player could not play,
    // so they are not retried in this session
    property var nativeFailed: ({})
    property bool dirReady

    function isVideo(path: string): bool {
        const lower = path.toLowerCase();
        return extensions.some(e => lower.endsWith(`.${e}`));
    }

    function isPoster(path: string): bool {
        return path.includes(`${postersDir}/`);
    }

    // Where a video's poster lives, whether it has been made yet or not
    function posterPath(path: string): string {
        return `${postersDir}/${Qt.md5(path)}.jpg`;
    }

    // An image as it is; a video's poster once it exists, else an empty string. A video
    // that has no poster because ffmpeg cannot read it gets the shell's own wallpaper.
    function still(path: string): string {
        if (!path || !isVideo(path))
            return path;
        const poster = posterPath(path);
        if (root.posters.has(poster))
            return poster;
        return root.failed[path] ? root.fallback : "";
    }

    // Where a video's played copy lives, whether it has been made yet or not
    function nativePath(path: string): string {
        return `${nativeDir}/${Qt.md5(path)}.mp4`;
    }

    // The file the background plays for a video: its copy once it exists and has not
    // failed to play, else an empty string (the poster shows)
    function playable(path: string): string {
        if (!root.playVideos || !path || !isVideo(path) || root.nativeFailed[path])
            return "";
        const copy = nativePath(path);
        return root.natives.has(copy) ? copy : "";
    }

    // Called by the background when the player gives up on a video's copy
    function markUnplayable(path: string): void {
        if (!path || root.nativeFailed[path])
            return;
        console.warn(`VideoWallpapers: ${path} does not play, the poster stays`);
        root.nativeFailed = Object.assign({}, root.nativeFailed, {
            [path]: true
        });
    }

    // What the colour preview should read: the poster is far quicker for the CLI than
    // the video, which it hashes in full before it decodes the first frame
    function colourSource(path: string): string {
        return still(path) || path;
    }

    // Queues a poster and the played copy. An urgent one (the wallpaper on screen) goes
    // to the front.
    function request(path: string, urgent: bool): void {
        if (!path || !isVideo(path))
            return;
        if (!root.failed[path] && !root.posters.has(posterPath(path))) {
            const rest = root.queue.filter(p => p !== path);
            root.queue = urgent ? [path].concat(rest) : rest.concat([path]);
        }
        if (!root.nativeFailed[path] && !root.natives.has(nativePath(path))) {
            const rest = root.nativeQueue.filter(p => p !== path);
            root.nativeQueue = urgent ? [path].concat(rest) : rest.concat([path]);
        }
        makeNext();
    }

    function requestAll(): void {
        for (const entry of videos.entries)
            request(entry.path, false);
    }

    // One ffmpeg at a time: all the posters first (they take well under a second), then
    // the played copies
    function makeNext(): void {
        if (!root.dirReady || maker.running || transcoder.running)
            return;
        while (root.queue.length > 0) {
            const video = root.queue[0];
            root.queue = root.queue.slice(1);
            if (root.posters.has(posterPath(video)) || root.failed[video])
                continue;
            maker.video = video;
            // Paths go in as arguments, never spliced into the script
            maker.command = ["nice", "-n", "19", "sh", "-c", maker.script, "sh", video, posterPath(video), String(root.posterWidth)];
            maker.running = true;
            return;
        }
        while (root.nativeQueue.length > 0) {
            const video = root.nativeQueue[0];
            root.nativeQueue = root.nativeQueue.slice(1);
            if (root.natives.has(nativePath(video)) || root.nativeFailed[video] || root.failed[video])
                continue;
            transcoder.video = video;
            transcoder.command = ["nice", "-n", "19", "ionice", "-c", "3", Quickshell.shellPath("custom/wallpaper/video-native.sh"), video, nativePath(video), String(root.nativeWidth), String(root.nativeHeight), String(root.nativeFps)];
            transcoder.running = true;
            return;
        }
    }

    // The cache directories have to exist before the models can watch them. Empty
    // files go first: a power loss right after ffmpeg finished can leave a poster or a
    // copy with its name but none of its data, and the models only notice new names.
    Process {
        running: true
        command: ["sh", "-c", 'mkdir -p "$1" "$2" && find "$1" "$2" -maxdepth 1 -type f -size 0 -delete', "sh", root.postersDir, root.nativeDir]
        onExited: {
            root.dirReady = true;
            postersModel.path = root.postersDir;
            nativesModel.path = root.nativeDir;
            root.requestAll();
        }
    }

    FileSystemModel {
        id: nativesModel

        filter: FileSystemModel.Files
        nameFilters: ["*.mp4"]

        onEntriesChanged: root.natives = new Set(Array.from(entries).map(e => e.path))
    }

    FileSystemModel {
        id: postersModel

        filter: FileSystemModel.Files
        nameFilters: ["*.jpg"]

        onEntriesChanged: root.posters = new Set(Array.from(entries).map(e => e.path))
    }

    FileSystemModel {
        id: videos

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Files
        nameFilters: root.extensions.map(e => `*.${e}`).concat(root.extensions.map(e => `*.${e.toUpperCase()}`))

        onEntriesChanged: root.requestAll()
    }

    Process {
        id: maker

        // $1 video, $2 poster, $3 width. ffmpeg writes next to the poster, the data is
        // flushed and the file renamed into place, so a reader never sees half a JPEG,
        // not even after a power loss. Exits 0 when the poster exists.
        readonly property string script: 'v=$1 p=$2 w=$3; [ -s "$p" ] || { ffmpeg -nostdin -hide_banner -loglevel error -threads 2 -y -i "$v" -frames:v 1 -vf "scale=min($w\\,iw):-2" -q:v 3 -f image2 -c:v mjpeg "$p.part" && sync "$p.part" && mv -f "$p.part" "$p"; }; rm -f "$p.part"; [ -s "$p" ]'
        property string video

        onExited: code => {
            if (code !== 0) {
                root.failed = Object.assign({}, root.failed, {
                    [video]: true
                });
                console.warn(`VideoWallpapers: no poster for ${video} (ffmpeg exit ${code})`);
            }
            root.makeNext();
        }
    }

    Process {
        id: transcoder

        property string video

        onExited: code => {
            if (code !== 0) {
                root.nativeFailed = Object.assign({}, root.nativeFailed, {
                    [video]: true
                });
                console.warn(`VideoWallpapers: no played copy of ${video} (exit ${code})`);
            }
            root.makeNext();
        }
    }
}
