pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs.components
import qs.services
import qs.custom.wallpaper

// Plays a video wallpaper, muted and looped, over the background's image layer, which
// shows the video's poster frame meanwhile.
//
// Two slots let one video cross-fade into the next: the new one loads in the back slot
// and fades in over the old one once its first frame is up, then the old one fades out
// and is unloaded. When an image replaces the video, the video fades out over the image
// layer's own cross-fade. Every slot builds a fresh player for every video, so a frame
// of the previous video can never show.
Item {
    id: root

    // Absolute path of the video, empty for image wallpapers
    required property string source

    readonly property HyprlandMonitor monitor: {
        const screen = (QsWindow.window as QsWindow)?.screen ?? null;
        return screen ? Hypr.monitorFor(screen) : null;
    }
    readonly property bool fullscreen: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool shouldPlay: !VideoWallpapers.sessionLocked && !(VideoWallpapers.pauseWhenFullscreen && fullscreen) && !(VideoWallpapers.pauseOnBattery && UPower.onBattery)
    readonly property bool suspended: VideoWallpapers.unloadWhenPaused && !shouldPlay

    // The video the slots are asked to show. A launcher preview gets there only once
    // the selection rests on it, so scrolling past videos starts no decoders.
    property string target
    property VideoSlot front: null

    function show(path: string): void {
        if (!path) {
            slotA.wanted = false;
            slotB.wanted = false;
            return;
        }

        if (root.front && root.front.path === path) {
            root.front.wanted = true;
            (root.front === slotA ? slotB : slotA).wanted = false;
            return;
        }

        const back = root.front === slotA ? slotB : slotA;
        back.z = 1;
        if (root.front)
            root.front.z = 0;
        back.path = path;
        back.wanted = true;
    }

    // Called by a slot once its first frame is up: it becomes the front one
    function promote(slot: VideoSlot): void {
        const old = root.front;
        root.front = slot;
        if (old && old !== slot)
            old.wanted = false;
    }

    onSourceChanged: {
        if (Wallpapers.showPreview && source) {
            delay.restart();
        } else {
            delay.stop();
            target = source;
        }
    }
    onTargetChanged: show(target)
    Component.onCompleted: target = source

    Timer {
        id: delay

        interval: VideoWallpapers.previewDelay
        onTriggered: root.target = root.source
    }

    VideoSlot {
        id: slotA
    }

    VideoSlot {
        id: slotB
    }

    component VideoSlot: Item {
        id: slot

        property string path
        property bool wanted
        // The first frame of `path` is up
        property bool ready
        readonly property bool live: path.length > 0 && (wanted || opacity > 0) && !root.suspended

        anchors.fill: parent
        opacity: wanted && ready ? 1 : 0

        onReadyChanged: {
            if (ready && wanted)
                root.promote(slot);
        }
        // A new video gets a new player
        onPathChanged: {
            ready = false;
            loader.active = false;
            loader.active = Qt.binding(() => slot.live);
        }

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }

        Loader {
            id: loader

            anchors.fill: parent
            active: slot.live
            onActiveChanged: {
                if (!active)
                    slot.ready = false;
            }

            sourceComponent: Item {
                Component.onCompleted: {
                    if (root.shouldPlay)
                        media.play();
                }

                VideoOutput {
                    id: output

                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectCrop
                }

                // No audio output, so no audio stream is opened at all
                MediaPlayer {
                    id: media

                    source: `file://${slot.path.split("/").map(encodeURIComponent).join("/")}`
                    videoOutput: output
                    loops: MediaPlayer.Infinite

                    onErrorOccurred: (error, errorString) => console.warn(`VideoLayer: ${slot.path}: ${errorString}`)
                }

                Connections {
                    function onVideoFrameChanged(): void {
                        slot.ready = true;
                    }

                    target: output.videoSink
                    enabled: !slot.ready
                }

                Connections {
                    function onShouldPlayChanged(): void {
                        if (root.shouldPlay)
                            media.play();
                        else
                            media.pause();
                    }

                    target: root
                }
            }
        }
    }
}
