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
            one.update();
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
                spacing: Tokens.spacing.large

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Tokens.font.size.extraLarge * 5
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.palette.m3onSurfaceVariant
                        font.pointSize: Tokens.font.size.extraLarge * 2
                        font.bold: true
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.large * 2
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small * 2

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
                            font.pointSize: Tokens.font.size.large
                        }
                    }
                }
            }
        }
    }

    Img {
        id: one
    }

    Img {
        id: two
    }

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

        anchors.fill: parent

        opacity: 0
        scale: Wallpapers.showPreview ? 1 : 0.8

        onStatusChanged: {
            if (status === Image.Ready)
                root.current = this;
        }

        states: State {
            name: "visible"
            when: root.current === img

            PropertyChanges {
                img.opacity: 1
                img.scale: 1
            }
        }

        transitions: Transition {
            Anim {
                target: img
                properties: "opacity,scale"
            }
        }
    }
}
