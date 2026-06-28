pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services
import qs.modules.bar

StyledWindow {
    id: root

    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool hasSpecialWorkspace: (monitor?.lastIpcObject.specialWorkspace?.name.length ?? 0) > 0
    readonly property bool hasFullscreenOnNormalWs: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool hasFullscreen: {
        if (hasSpecialWorkspace) {
            const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
            if (!specialName)
                return false;
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return hasFullscreenOnNormalWs;
    }

    property real fsTransitionProg: hasFullscreen ? 1 : 0
    readonly property real sdfBorderOffset: 2 * fsTransitionProg // SDFs joins are not exact, so offset by 2px to ensure nothing shows
    readonly property real borderThickness: contentItem.Config.border.thickness * (1 - fsTransitionProg)
    readonly property real borderRounding: contentItem.Config.border.rounding * (1 - fsTransitionProg)
    readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : contentItem.Config.border.thickness

    property color surfaceColour: Colours.tPalette.m3surface

    readonly property int dragMaskPadding: {
        if (focusGrab.active || panels.popouts.isDetached)
            return 0;

        if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace?.lastIpcObject.windows > 0)
            return 0;

        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (contentItem.Config[panel].enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold);
        return Math.max(...thresholds);
    }

    onHasFullscreenChanged: {
        visibilities.launcher = false;
        visibilities.session = false;
        visibilities.dashboard = false;
        panels.popouts.close();
    }

    name: "drawers"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: (fsTransitionProg > 0 && contentItem.Config.general.showOverFullscreen) || (hasSpecialWorkspace && hasFullscreenOnNormalWs) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: visibilities.launcher || visibilities.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: hasFullscreen ? emptyRegion : regions

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on fsTransitionProg {
        Anim {}
    }

    Behavior on surfaceColour {
        CAnim {}
    }

    Region {
        id: emptyRegion

        x: panels.notifications.x + root.borderThickness
        y: panels.notifications.y + bar.implicitHeight
        width: panels.notifications.width
        height: panels.notifications.height

        Region {
            x: panels.osdWrapper.x + root.borderThickness
            y: root.height - height
            width: panels.osd.width
            height: panels.osdWrapper.height * (1 - panels.osd.offsetScale) + root.borderThickness
        }
    }

    Regions {
        id: regions

        bar: bar
        panels: panels
        win: root
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: (visibilities.launcher && root.contentItem.Config.launcher.enabled) || (visibilities.session && root.contentItem.Config.session.enabled) || (visibilities.sidebar && root.contentItem.Config.sidebar.enabled) || (!root.contentItem.Config.dashboard.showOnHover && visibilities.dashboard && root.contentItem.Config.dashboard.enabled) || (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1)
        windows: [root]
        onCleared: {
            visibilities.launcher = false;
            visibilities.session = false;
            visibilities.sidebar = false;
            visibilities.dashboard = false;
            panels.popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: (visibilities.session && Config.session.enabled) || panels.popouts.detachedMode !== "" ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.surfaceColour.a
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        BlobGroup {
            id: blobGroup

            color: root.surfaceColour
            smoothing: root.contentItem.Config.border.smoothing
        }

        BlobInvertedRect {
            id: screenBorderBlob
            anchors.fill: parent
            anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
            group: blobGroup
            radius: root.borderRounding
            borderLeft: root.borderThickness - anchors.margins - root.sdfBorderOffset
            borderRight: root.borderThickness - anchors.margins - root.sdfBorderOffset
            borderTop: root.borderThickness - anchors.margins - root.sdfBorderOffset
            borderBottom: root.borderThickness - anchors.margins - root.sdfBorderOffset
        }

        PanelBg {
            id: dashBg
            panel: panels.dashboard
            deformAmount: 0.1
        }

        PanelBg {
            id: launcherBg
            panel: panels.launcher
            deformAmount: 0.1
        }

        PanelBg {
            id: sessionBg
            panel: panels.sessionWrapper
            deformAmount: 0.2
        }

        PanelBg {
            id: sidebarBg
            panel: panels.sidebar
            implicitHeight: panel.height + 2
        }

        PanelBg {
            id: osdBg
            panel: panels.osdWrapper
            deformAmount: 0.25
        }

        PanelBg {
            id: notifsBg
            panel: panels.notifications
        }

        PanelBg {
            id: utilsBg
            panel: panels.utilities
        }

        PanelBg {
            id: popoutBg
            panel: panels.popoutsWrapper
        }

        Rectangle {
            id: workspacesBg
            x: bar.workspacesX
            y: bar.y + (bar.implicitHeight - implicitHeight) / 2
            implicitWidth: bar.workspacesWidth
            implicitHeight: Tokens.sizes.bar.innerWidth
            radius: Tokens.rounding.full
            color: Qt.alpha(root.surfaceColour, 1)
            visible: bar.workspacesWidth > 0
        }

        Rectangle {
            id: barBg
            x: bar.rightPartX
            y: bar.y
            implicitWidth: bar.width - bar.rightPartX
            implicitHeight: bar.implicitHeight
            radius: root.borderRounding
            color: Qt.alpha(root.surfaceColour, 1)
        }
    }

    DrawerVisibilities {
        id: visibilities

        Component.onCompleted: Visibilities.load(root.screen, this)
    }

    Interactions {
        id: interactions

        screen: root.screen
        popouts: panels.popouts
        visibilities: visibilities
        panels: panels
        bar: bar
        borderThickness: root.borderLayoutThickness
        fullscreen: root.hasFullscreen

        Panels {
            id: panels

            screen: root.screen
            visibilities: visibilities
            bar: bar
            borderThickness: root.borderThickness

            utilities.horizontalStretch: 1
        }

        BarWrapper {
            id: bar

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            screen: root.screen
            visibilities: visibilities
            popouts: panels.popouts

            fullscreen: root.hasFullscreen

            Component.onCompleted: Visibilities.bars.set(root.screen, this)
        }
    }

    component PanelBg: Rectangle {
        required property Item panel
        property real deformAmount: 0.15

        color: Qt.alpha(root.surfaceColour, 1)
        x: panel.x + root.borderThickness
        y: panel.y + bar.implicitHeight
        implicitWidth: panel.width
        implicitHeight: panel.height
        radius: Tokens.rounding.extraLarge
        visible: panel.visible
        opacity: panel.opacity !== undefined ? panel.opacity : 1
    }
}
