pragma ComponentBehavior: Bound

import qs.custom
import qs.custom.bar
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

    // [fork] EZ AZ EGYETLEN VÁLTÓ a vertikális (upstream, bal szél) és a
    // vízszintes (fork, felső szél) bar között.
    // Forrás: ~/.config/caelestia/extras.json → { "bar": { "horizontal": true } }
    readonly property bool horizontal: ExtrasConfig.horizontalBar

    readonly property bool disabled: Strings.testRegexList(Config.bar.excludedScreens, screen.name)

    readonly property int clampedWidth: Math.max(Config.border.minThickness, implicitWidth)
    readonly property int padding: Math.max(Tokens.padding.small, Config.border.thickness)
    readonly property int contentWidth: Tokens.sizes.bar.innerWidth + padding * 2
    readonly property int exclusiveZone: !disabled && (Config.bar.persistent || screenState.bar) ? contentWidth : Config.border.thickness
    readonly property bool shouldBeVisible: !fullscreen && !disabled && (Config.bar.persistent || screenState.bar || isHovered)
    property bool isHovered

    // [fork] A vízszintes mód párjai. A contentWidth-et a bar "vastagságaként"
    // használjuk mindkét irányban, csak más tengelyen.
    readonly property int clampedHeight: Math.max(Config.border.minThickness, implicitHeight)

    // [fork] Csak a vízszintes bar szolgáltatja (a sziget-háttér geometriájához)
    readonly property real rightPartX: (content.item as HBar)?.rightPartX ?? (width / 2)
    readonly property int hPadding: (content.item as HBar)?.hPadding ?? padding

    // Mindkét változat ugyanezt a három függvényt kínálja. A hívó dönti el, hogy
    // x-et vagy y-t ad át (vízszintesnél x, vertikálisnál y).
    function closeTray(): void {
        content.item?.closeTray();
    }

    function checkPopout(coord: real): void {
        content.item?.checkPopout(coord);
    }

    function handleWheel(coord: real, angleDelta: point): void {
        content.item?.handleWheel(coord, angleDelta);
    }

    clip: true

    visible: horizontal ? height > Config.border.thickness : width > Config.border.thickness

    implicitWidth: horizontal ? 0 : (fullscreen ? 0 : Config.border.thickness)
    implicitHeight: horizontal ? (fullscreen ? 0 : Config.border.thickness) : 0

    states: State {
        name: "visible"
        when: root.shouldBeVisible

        PropertyChanges {
            root.implicitWidth: root.horizontal ? 0 : root.contentWidth
            root.implicitHeight: root.horizontal ? root.contentWidth : 0
        }
    }

    transitions: [
        Transition {
            from: ""
            to: "visible"

            Anim {
                target: root
                property: root.horizontal ? "implicitHeight" : "implicitWidth"
            }
        },
        Transition {
            from: "visible"
            to: ""

            Anim {
                target: root
                property: root.horizontal ? "implicitHeight" : "implicitWidth"
                type: Anim.Emphasized
            }
        }
    ]

    // FONTOS: itt NEM használunk feltételes anchort. A QML-ben az
    // `anchors.x: cond ? parent.y : undefined` NEM törli az anchort, ezért a
    // wrapper mindkét élre felfeszülne. Explicit x/y/width/height helyette.
    //
    // A bar a wrapper "belső" éléhez tapad, hogy előbújáskor becsúszzon:
    // vertikálisnál a jobb szélhez (upstream), vízszintesnél az alsóhoz.
    Loader {
        id: content

        width: root.horizontal ? root.width : root.contentWidth
        height: root.horizontal ? root.contentWidth : root.height
        x: root.horizontal ? 0 : root.width - width
        y: root.horizontal ? root.height - height : 0

        active: root.shouldBeVisible

        sourceComponent: root.horizontal ? horizontalBar : verticalBar
    }

    // [fork] A fork vízszintes barja (custom/bar/HBar.qml)
    Component {
        id: horizontalBar

        HBar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }

    // Az ÉRINTETLEN upstream vertikális bar (modules/bar/Bar.qml)
    Component {
        id: verticalBar

        Bar {
            screen: root.screen
            screenState: root.screenState
            popouts: root.popouts // qmllint disable incompatible-type
            fullscreen: root.fullscreen
        }
    }
}
