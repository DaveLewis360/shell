pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness

    // [fork] The bar takes the left edge, or the top one when horizontal
    readonly property real leftEdge: bar.horizontal ? clampedThickness : bar.clampedWidth
    readonly property real topEdge: bar.horizontal ? bar.clampedWidth : clampedThickness

    x: leftEdge + win.dragMaskPadding
    y: topEdge + win.dragMaskPadding
    width: win.width - leftEdge - clampedThickness - win.dragMaskPadding * 2
    height: win.height - topEdge - clampedThickness - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: (panel.height - root.panels.dashboard.barOverlap) * (1 - root.panels.dashboard.offsetScale) + root.bar.topInset(root.borderThickness) // [fork]
    }

    R {
        panel: root.panels.launcher
        y: root.win.height - height
        height: panel.height * (1 - root.panels.launcher.offsetScale) + root.borderThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: panel.width * (1 - root.panels.sidebar.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: panel.width * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: panel.height + root.bar.topInset(root.borderThickness) // [fork]
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: panel.height * (1 - root.panels.utilities.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        // [fork] A popout under a top bar collapses vertically
        width: panel.width * (root.bar.horizontal ? 1 : 1 - root.panels.popoutsWrapper.offsetScale)
        height: panel.height * (root.bar.horizontal ? 1 - root.panels.popoutsWrapper.offsetScale : 1)
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.leftInset(root.borderThickness) // [fork]
        y: panel.y + root.bar.topInset(root.borderThickness) // [fork]
        width: panel.width
        height: panel.height
        intersection: Intersection.Subtract
    }
}
