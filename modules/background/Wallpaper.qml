pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    property string source: Wallpapers.current
    readonly property bool isVideo: root.source ? Images.isVideoByName(root.source) : false

    // The image the picture layers display. Holds the last *image* path: while a video plays it
    // stays put (the video layer covers it), so the image layers never load a video and the
    // video->image transition never flashes black. Empty only when there is no wallpaper at all.
    property string imageSource: ""

    property Image current: one
    property bool completed

    onSourceChanged: {
        // Compute the type from the fresh `source`: the `isVideo` binding lags one change behind
        // inside this handler, which previously let a video leak into imageSource (-> black).
        if (!root.source)
            root.imageSource = "";
        else if (!Images.isVideoByName(root.source))
            root.imageSource = root.source;
        // video: keep imageSource as the last image
    }

    onImageSourceChanged: {
        if (!root.imageSource) {
            root.current = null;
            return;
        }
        if (root.current === one)
            two.update();
        else
            current = imgComp.createObject(this, {
                path: source
            });
    }

    Component.onCompleted: {
        if (root.source && !Images.isVideoByName(root.source))
            root.imageSource = root.source;
        completed = true;
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.palette.m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Media files")
                            filters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.mp4", "*.webm", "*.mkv", "*.mov", "*.gif"]
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.palette.m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.palette.m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

    // Native video wallpaper: rendered in-window, per-monitor (via Background's Variants),
    // so no external process, no layer-ordering issues, no monitor race.
    Loader {
        anchors.fill: parent
        active: root.isVideo

        sourceComponent: Item {
            // Opaque base so the image layer underneath can never bleed through ("random image").
            Rectangle {
                anchors.fill: parent
                color: "black"
            }

            // Poster frame of the *current source* (preview-aware) until the first video frame.
            CachingImage {
                anchors.fill: parent
                path: Wallpapers.thumbFor(root.source)
                fillMode: Image.PreserveAspectCrop
            }

            VideoOutput {
                id: videoOut

                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop
            }

            MediaPlayer {
                videoOutput: videoOut
                source: root.source ? Qt.resolvedUrl(root.source) : ""
                loops: MediaPlayer.Infinite
                audioOutput: AudioOutput {
                    muted: true
                }
                // Qt6 has no autoPlay: start once media has loaded. Covers the video->video case
                // where the Loader keeps one instance and only the source changes.
                onMediaStatusChanged: if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) play()
            }
        }
    }

    component Img: CachingImage {
        id: img

        function update(): void {
            if (!root.imageSource)
                return;
            if (path === root.imageSource)
                root.current = this;
            else
                path = root.imageSource;
        }

            onStatusChanged: {
                if (status === Image.Ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
            }

            Timer {
                running: root.current !== img && root.current?.status === Image.Ready
                interval: anim.duration
                onTriggered: img.destroy()
            }
        }
    }
}
