import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.effects
import qs.components.images
import qs.services

Item {
    id: root

    required property FileSystemEntry modelData
    required property DrawerVisibilities visibilities

    readonly property bool isVideo: {
        const ext = modelData.path.split('.').pop().toLowerCase();
        return ["mp4", "webm", "mkv", "mov", "gif"].includes(ext);
    }

    scale: 0.5
    opacity: 0
    z: PathView.z ?? 0 // qmllint disable missing-property

    Component.onCompleted: {
        scale = Qt.binding(() => PathView.isCurrentItem ? 1 : PathView.onPath ? 0.8 : 0);
        opacity = Qt.binding(() => PathView.onPath ? 1 : 0);
    }

    implicitWidth: image.width + Tokens.padding.larger * 2
    implicitHeight: image.height + label.height + Tokens.spacing.small / 2 + Tokens.padding.large + Tokens.padding.normal

    StateLayer {
        radius: Tokens.rounding.normal
        onClicked: {
            Wallpapers.setWallpaper(root.modelData.path);
            root.visibilities.launcher = false;
        }
    }

    Elevation {
        anchors.fill: image
        radius: image.radius
        opacity: root.PathView.isCurrentItem ? 1 : 0
        level: 4

        Behavior on opacity {
            Anim {}
        }
    }

    StyledClippingRect {
        id: image

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.large
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.normal

        implicitWidth: Tokens.sizes.launcher.wallpaperWidth
        implicitHeight: implicitWidth / 16 * 9

        MaterialIcon {
            anchors.centerIn: parent
            text: isVideo && !thumbCachingImage.status === Image.Ready ? "play_circle" : "image"
            color: Colours.tPalette.m3outline
            font.pointSize: Tokens.font.size.extraLarge * 2
            font.weight: 600
            visible: !thumbCachingImage.status === Image.Ready
        }

        CachingImage {
            anchors.fill: parent
            path: !isVideo ? root.modelData.path : ""
            smooth: !root.PathView.view.moving
            sourceSize: {
                const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                return Qt.size(image.implicitWidth * dpr, image.implicitHeight * dpr);
            }
        }

        CachingImage {
            id: thumbCachingImage
            anchors.fill: parent
            path: isVideo ? `/tmp/wallthumbs/${Qt.md5(root.modelData.path)}.jpg` : ""
            smooth: !root.PathView.view.moving
            sourceSize: {
                const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                return Qt.size(image.implicitWidth * dpr, image.implicitHeight * dpr);
            }
        }

        Process {
            id: launcherThumbProc
            command: ["bash", "-c", `mkdir -p /tmp/wallthumbs && ffmpeg -y -i '${root.modelData.path}' -vframes 1 -q:v 2 '/tmp/wallthumbs/${Qt.md5(root.modelData.path)}.jpg'`]
            running: isVideo
            onExited: (ok, status) => {
                if (ok) {
                    thumbCachingImage.path = "";
                    thumbCachingImage.path = `/tmp/wallthumbs/${Qt.md5(root.modelData.path)}.jpg`;
                }
            }
        }
    }

    StyledText {
        id: label

        anchors.top: image.bottom
        anchors.topMargin: Tokens.spacing.small / 2
        anchors.horizontalCenter: parent.horizontalCenter

        width: image.width - Tokens.padding.normal * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        renderType: Text.QtRendering
        text: root.modelData.relativePath
        font.pointSize: Tokens.font.size.normal
    }

    Behavior on scale {
        Anim {}
    }

    Behavior on opacity {
        Anim {}
    }
}
