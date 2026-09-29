pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.utils
import qs.modules.bar.popouts as BarPopouts
import qs.custom.bar as Fork // [fork]

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    // [fork] Top bar (custom/bar). `implicitWidth` stays the bar's animated thickness
    // in both orientations; the drawers ask leftInset()/topInset() for the space the
    // bar takes instead of assuming it sits on the left.
    readonly property bool horizontal: GlobalConfig.fork.bar.horizontal

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int clampedWidth: Math.max(Config.border.minThickness, implicitWidth)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentWidth : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered

    // [fork] Space the bar takes from the left/top edge, given the border thickness
    // the caller uses for the other edges.
    function leftInset(border: real): real {
        return horizontal ? border : implicitWidth;
    }

    function topInset(border: real): real {
        return horizontal ? implicitWidth : border;
    }

    function closeTray(): void {
        (content.item as Bar)?.closeTray();
        (hContent.item as Fork.HBar)?.closeTray(); // [fork]
    }

    // [fork] For the top bar, `y` is the position along the bar, i.e. x
    function checkPopout(y: real): void {
        (content.item as Bar)?.checkPopout(y);
        (hContent.item as Fork.HBar)?.checkPopout(y); // [fork]
    }

    function handleWheel(y: real, angleDelta: point): void {
        (content.item as Bar)?.handleWheel(y, angleDelta);
        (hContent.item as Fork.HBar)?.handleWheel(y, angleDelta); // [fork]
    }

    clip: true
    visible: (horizontal ? height : width) > Config.border.thickness // [fork] horizontal
    implicitWidth: fullscreen ? 0 : Config.border.thickness

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitWidth: root.contentWidth
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: "implicitWidth"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: "implicitWidth"
                type: Anim.Emphasized
            }
        }
    ]

    Loader {
        id: content

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right

        active: root.shouldBeVisible && !root.horizontal // [fork] !horizontal

        sourceComponent: Bar {
            width: root.contentWidth
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts
            fullscreen: root.fullscreen
        }
    }

    // [fork] The top bar hangs from the bottom edge, so it slides down into view as
    // the wrapper grows, the way the upstream bar slides in from the left.
    Loader {
        id: hContent

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        active: root.shouldBeVisible && root.horizontal

        sourceComponent: Fork.HBar {
            height: root.contentWidth
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
