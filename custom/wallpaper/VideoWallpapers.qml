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
Singleton {
    id: root

    // Behaviour switches. Each one changes what can be seen, so they keep the old
    // behaviour (always play) until it is decided otherwise.
    // Pause the video while a fullscreen window covers its monitor
    readonly property bool pauseWhenFullscreen: false
    // Pause the video while the laptop runs on battery
    readonly property bool pauseOnBattery: false
    // Stop the player instead of pausing it. That frees its memory (about 650 MB for a
    // 4K video) and lets the GPU decoder idle, but the video starts again from its
    // poster when it resumes.
    readonly property bool unloadWhenPaused: false
    // How long the launcher has to rest on a video before the background plays it (ms).
    // Its poster shows at once either way.
    readonly property int previewDelay: 300

    // The video types of the caelestia CLI (VIDEO_EXTENSIONS) that Qt plays, so avi is left out
    readonly property list<string> extensions: ["mp4", "webm", "mkv", "mov"]
    readonly property string postersDir: `${Paths.cache}/wallpaper/video-posters`
    // Wider than any picker cell, enough for the blurred lock screen; the live video
    // covers the poster within a fraction of a second on the desktop
    readonly property int posterWidth: 1920
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

    // An image as it is; a video's poster once it exists, else an empty string
    function still(path: string): string {
        if (!path || !isVideo(path))
            return path;
        const poster = posterPath(path);
        return root.posters.has(poster) ? poster : "";
    }

    // What the colour preview should read: the poster is far quicker for the CLI than
    // the video, which it hashes in full before it decodes the first frame
    function colourSource(path: string): string {
        return still(path) || path;
    }

    // Queues a poster. An urgent one (the wallpaper on screen) goes to the front.
    function request(path: string, urgent: bool): void {
        if (!path || !isVideo(path) || root.failed[path] || root.posters.has(posterPath(path)))
            return;
        const rest = root.queue.filter(p => p !== path);
        root.queue = urgent ? [path].concat(rest) : rest.concat([path]);
        makeNext();
    }

    function requestAll(): void {
        for (const entry of videos.entries)
            request(entry.path, false);
    }

    function makeNext(): void {
        if (!root.dirReady || maker.running)
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
    }

    // The posters directory has to exist before the model can watch it
    Process {
        running: true
        command: ["mkdir", "-p", root.postersDir]
        onExited: {
            root.dirReady = true;
            postersModel.path = root.postersDir;
            root.requestAll();
        }
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

        // $1 video, $2 poster, $3 width. ffmpeg writes next to the poster and the file
        // is renamed into place, so a reader never sees half a JPEG. Exits 0 when the
        // poster exists.
        readonly property string script: 'v=$1 p=$2 w=$3; [ -s "$p" ] || { ffmpeg -nostdin -hide_banner -loglevel error -threads 2 -y -i "$v" -frames:v 1 -vf "scale=min($w\\,iw):-2" -q:v 3 -f image2 -c:v mjpeg "$p.part" && mv -f "$p.part" "$p"; }; rm -f "$p.part"; [ -s "$p" ]'
        property string video

        onExited: code => {
            if (code !== 0) {
                root.failed[video] = true;
                console.warn(`VideoWallpapers: no poster for ${video} (ffmpeg exit ${code})`);
            }
            root.makeNext();
        }
    }
}
