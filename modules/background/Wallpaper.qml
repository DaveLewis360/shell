pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    property string source: Wallpapers.current
    property Image current: one
    property bool completed

    function isVideoPath(path: string): bool {
        const ext = path.split('.').pop().toLowerCase();
        return ["mp4", "webm", "mkv", "mov", "gif"].includes(ext);
    }

    onSourceChanged: {
        if (!source)
            current = null;
        else if (current === one)
            two.update();
        else
            one.update();
    }

    Component.onCompleted: {
        if (source)
            Qt.callLater(() => {
                one.update();
                completed = true;
            });
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

    component Img: CachingImage {
        id: img

        property bool isVideoSource: false

        function update(): void {
            isVideoSource = root.isVideoPath(root.source);

            if (!isVideoSource) {
                path = root.source;
            } else {
                path = "";
            }

            if (path === root.source || isVideoSource)
                root.current = this;
        }

        anchors.fill: parent

        opacity: (root.current === img && !img.isVideoSource) ? 1 : 0
        scale: (root.current === img) ? 1 : (Wallpapers.showPreview ? 1 : 0.8)

        onStatusChanged: {
            if (status === Image.Ready)
                root.current = this;
        }

        onIsVideoSourceChanged: {
            if (isVideoSource)
                root.current = this;
        }

        transitions: Transition {
            Anim {
                target: img
                properties: "opacity,scale"
            }
        }
    }
}
