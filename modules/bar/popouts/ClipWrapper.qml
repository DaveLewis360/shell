pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config // [fork]
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    readonly property alias content: content
    property real offsetScale: x > 0 || content.hasCurrent ? 0 : 1

    // [fork] Position along a top bar, centred on the hovered item and kept on screen
    function xUnderBar(): real {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimWidth / 2;
        const diff = parent.width - Math.floor(off + content.nonAnimWidth);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth * (1 - offsetScale)
    implicitHeight: content.implicitHeight

    x: content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : 0
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    // [fork] Under a top bar the popout hangs below the hovered item and grows
    // downwards (custom/bar)
    states: State {
        when: GlobalConfig.fork.bar.horizontal

        PropertyChanges {
            root.offsetScale: root.y > 0 || content.hasCurrent ? 0 : 1
            root.implicitWidth: content.implicitWidth
            root.implicitHeight: content.implicitHeight * (1 - root.offsetScale)
            root.x: root.xUnderBar()
            root.y: content.isDetached ? (root.parent.height - content.nonAnimHeight) / 2 : 0
            content.anchors.leftMargin: 0
            content.anchors.topMargin: (-content.implicitHeight - 5) * root.offsetScale
        }

        AnchorChanges {
            target: content
            anchors.verticalCenter: undefined
            anchors.left: undefined
            anchors.horizontalCenter: root.horizontalCenter
            anchors.top: root.top
        }
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: (-implicitWidth - 5) * root.offsetScale
    }
}
