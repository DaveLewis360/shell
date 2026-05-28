pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.utils

Item {
    id: root

    required property DrawerVisibilities visibilities
    readonly property bool needsKeyboard: (content.item as Content)?.needsKeyboard ?? false
    readonly property DashboardState dashState: DashboardState {
        reloadableId: "dashboardState"
    }
    readonly property FileDialog facePicker: FileDialog {
        title: qsTr("Select a profile picture")
        filterLabel: qsTr("Image files")
        filters: Images.validImageExtensions
        onAccepted: path => {
            if (CUtils.copyFile(Qt.resolvedUrl(path), Qt.resolvedUrl(`${Paths.home}/.face`)))
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "low", "-h", `STRING:image-path:${path}`, "Profile picture changed", `Profile picture changed to ${Paths.shortenHome(path)}`]);
            else
                Quickshell.execDetached(["notify-send", "-a", "caelestia-shell", "-u", "critical", "Unable to change profile picture", `Failed to change profile picture to ${Paths.shortenHome(path)}`]);
        }
    }

    readonly property real nonAnimHeight: shouldBeActive ? ((content.item as Content)?.nonAnimHeight ?? 0) : 0
    readonly property real nonAnimWidth: shouldBeActive ? ((content.item as Content)?.nonAnimWidth ?? 0) : 0
    readonly property bool shouldBeActive: visibilities.dashboard && Config.dashboard.enabled
    property real offsetScale: shouldBeActive ? 0 : 1

    clip: true
    visible: offsetScale < 1
    implicitHeight: content.implicitHeight * (1 - offsetScale)
    implicitWidth: content.implicitWidth || 854
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Loader {
        id: content

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            visibilities: root.visibilities
            dashState: root.dashState
            facePicker: root.facePicker
        }
    }
}
