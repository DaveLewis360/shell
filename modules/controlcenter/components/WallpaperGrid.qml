pragma ComponentBehavior: Bound

import ".."
import QtQuick
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.effects
import qs.components.images
import qs.services
import qs.utils
import Quickshell
import Quickshell.Io

GridView {
    id: root

    required property Session session

    readonly property int minCellWidth: 200 + Tokens.spacing.normal
    readonly property int columnsCount: Math.max(1, Math.floor(width / minCellWidth))

    cellWidth: width / columnsCount
    cellHeight: 140 + Tokens.spacing.normal

    model: Wallpapers.list

    clip: true
    focus: true
    keyNavigationWraps: true

    StyledScrollBar.vertical: StyledScrollBar {
        flickable: root
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            if (currentItem && currentItem.modelData)
                Wallpapers.setWallpaper(currentItem.modelData.path);
            event.accepted = true;
        }
    }

    delegate: Item {
        required property var modelData
        required property int index
        readonly property bool isCurrent: modelData && modelData.path === Wallpapers.actualCurrent
        readonly property real itemMargin: Tokens.spacing.normal / 2
        readonly property real itemRadius: Tokens.rounding.normal
        readonly property bool isVideo: Images.isVideoByName(modelData.path)

        width: root.cellWidth
        height: root.cellHeight

        StateLayer {
            onClicked: {
                Wallpapers.setWallpaper(modelData.path);
            }

            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            radius: itemRadius
        }

        StyledClippingRect {
            id: image

            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: Colours.tPalette.m3surfaceContainer
            radius: itemRadius
            antialiasing: true
            layer.enabled: true
            layer.smooth: true

            CachingImage {
                id: cachingImage

                path: isVideo ? videoThumb.thumbPath : modelData.path
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: opacity > 0
                antialiasing: true
                smooth: true
                sourceSize: Qt.size(width, height)

                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutQuad
                    }
                }
            }

            QtObject {
                id: videoThumb

                readonly property string thumbPath: isVideo ? Wallpapers.thumbFor(modelData.path) : ""
            }

            Process {
                id: genThumbProc

                command: ["bash", "-c", `mkdir -p '${Wallpapers.thumbsDir}'; [ -f '${videoThumb.thumbPath}' ] || ffmpeg -y -i '${modelData.path}' -vframes 1 -q:v 2 '${videoThumb.thumbPath}'`]
                running: isVideo

                onExited: (exitCode, exitStatus) => {
                    if (exitCode === 0) {
                        cachingImage.path = "";
                        cachingImage.path = videoThumb.thumbPath;
                    }
                }
            }

            // Play icon overlay for video files
            MaterialIcon {
                anchors.centerIn: parent
                text: "play_circle"
                color: Colours.palette.m3onSurface
                font.pointSize: Tokens.font.size.extraLarge * 3
                visible: isVideo && cachingImage.status !== Image.Ready
                opacity: 0.7

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }
            }

            // Fallback if CachingImage fails to load
            Image {
                id: fallbackImage

                anchors.fill: parent
                source: !isVideo && fallbackTimer.triggered && cachingImage.status !== Image.Ready ? modelData.path : ""
                asynchronous: true
                fillMode: Image.PreserveAspectCrop
                cache: true
                visible: opacity > 0
                antialiasing: true
                smooth: true
                sourceSize: Qt.size(width, height)

                opacity: status === Image.Ready && cachingImage.status !== Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutQuad
                    }
                }
            }

            Timer {
                id: fallbackTimer

                property bool triggered: false

                interval: 800
                running: cachingImage.status === Image.Loading || cachingImage.status === Image.Null
                onTriggered: triggered = true
            }

            // Gradient overlay for filename
            Rectangle {
                id: filenameOverlay

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                implicitHeight: filenameText.implicitHeight + Tokens.padding.normal * 1.5
                radius: 0

                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0)
                    }
                    GradientStop {
                        position: 0.3
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.7)
                    }
                    GradientStop {
                        position: 0.6
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.9)
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.rgba(Colours.palette.m3surface.r, Colours.palette.m3surface.g, Colours.palette.m3surface.b, 0.95)
                    }
                }

                opacity: 0

                Component.onCompleted: {
                    opacity = 1;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 1000
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: itemMargin
            anchors.rightMargin: itemMargin
            anchors.topMargin: itemMargin
            anchors.bottomMargin: itemMargin
            color: "transparent"
            radius: itemRadius + border.width
            border.width: isCurrent ? 2 : 0
            border.color: Colours.palette.m3primary
            antialiasing: true
            smooth: true

            Behavior on border.width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            MaterialIcon {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.padding.small

                visible: isCurrent
                text: "check_circle"
                color: Colours.palette.m3primary
                font.pointSize: Tokens.font.size.large
            }
        }

        StyledText {
            id: filenameText

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.padding.normal + Tokens.spacing.normal / 2
            anchors.rightMargin: Tokens.padding.normal + Tokens.spacing.normal / 2
            anchors.bottomMargin: Tokens.padding.normal

            text: isVideo ? "🎬 " + modelData.name : modelData.name
            font.pointSize: Tokens.font.size.smaller
            font.weight: 500
            color: isCurrent ? Colours.palette.m3primary : Colours.palette.m3onSurface
            elide: Text.ElideMiddle
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter

            opacity: 0

            Component.onCompleted: {
                opacity = 1;
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 1000
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
