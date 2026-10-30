pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import qs.components

Item {
    id: root

    required property ScreenState screenState
    readonly property Props props: Props {}

    readonly property bool shouldBeActive: screenState.chat
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.leftMargin: (-implicitWidth - 5) * offsetScale
    implicitWidth: Tokens.sizes.sidebar.width
    opacity: 1 - offsetScale

    // Same motion as the right-hand notification sidebar: the shell-default
    // DefaultSpatial token (500 ms), so both sidebars appear/hide identically.
    Behavior on offsetScale {
        Anim {}
    }

    // Keep the chat alive once built: rebuilding on every toggle meant a
    // socket reconnect, a fresh history replay and the transcript re-render
    // racing the slide-in animation. The cost of keeping it is one idle
    // socket connection.
    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.rightMargin: Tokens.padding.large
        anchors.margins: CUtils.clamp(anchors.rightMargin - Config.border.thickness, 0, anchors.rightMargin)
        anchors.bottomMargin: 0

        active: true

        sourceComponent: Content {
            implicitWidth: Tokens.sizes.sidebar.width - content.anchors.rightMargin - content.anchors.margins
            props: root.props
            screenState: root.screenState
        }
    }
}
