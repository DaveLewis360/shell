pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int clampedHeight: Math.max(Config.border.minThickness, implicitHeight)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentHeight: Tokens.sizes.bar.innerWidth + padding * 2 // [fork] vízszintes bar
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentHeight : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered

    readonly property real rightPartX: (content.item as Bar)?.rightPartX ?? (width / 2)
    readonly property real workspacesX: (content.item as Bar)?.workspacesX ?? 0
    readonly property real workspacesWidth: (content.item as Bar)?.workspacesWidth ?? 0
    readonly property int hPadding: (content.item as Bar)?.hPadding ?? padding

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
    }

    function checkPopout(x: real): void {
        (content.item as Bar)?.checkPopout(x);
    }

    function handleWheel(x: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(x, angleDelta);
    }

    clip: true
    visible: height >= (fullscreen ? 0 : Config.border.thickness)
    implicitHeight: fullscreen ? 0 : Config.border.thickness

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitHeight: root.contentHeight
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitHeight"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitHeight"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        active: root.shouldBeVisible || root.visible

        sourceComponent: Bar {
            height: root.contentHeight
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
