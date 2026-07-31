pragma ComponentBehavior: Bound

import "../../modules/bar/components"
import "../../modules/bar/components/workspaces"
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

StyledClippingRect {
    id: root

    required property ShellScreen screen
    required property bool fullscreen

    readonly property bool onSpecial: (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor)?.lastIpcObject.specialWorkspace?.name !== ""
    readonly property int activeWsId: GlobalConfig.bar.workspaces.perMonitorWorkspaces ? (Hypr.monitorFor(screen).activeWorkspace?.id ?? 1) : Hypr.activeWsId

    readonly property var occupied: {
        const occ = {};
        for (const ws of Hypr.workspaces.values)
            occ[ws.id] = ws.lastIpcObject.windows > 0;
        return occ;
    }
    readonly property int groupOffset: Math.floor((activeWsId - 1) / Config.bar.workspaces.shown) * Config.bar.workspaces.shown

    property real blur: onSpecial ? 1 : 0

    implicitHeight: Tokens.sizes.bar.innerWidth
    // [fork] Special workspace-en a sor akár szélesebb is lehet a normál
    // pöttyöknél (ikonok vs pöttyök), ezért a nagyobbat vesszük. A margót is
    // hozzáadjuk, amit a Loader levon, különben az utolsó ikon a maszk szélére
    // esik és elfakul.

    readonly property real specialContentWidth: root.onSpecial && specialWs.item ? (specialWs.item as HSpecialWorkspaces).contentWidth + Tokens.padding.extraSmall * 2 : 0

    implicitWidth: Math.max(layout.implicitWidth, specialContentWidth) + Tokens.padding.small

    Behavior on implicitWidth {
        Anim {}
    }

    color: "transparent"

    radius: Tokens.rounding.full

    Item {
        anchors.fill: parent
        scale: root.onSpecial ? 0.8 : 1
        opacity: root.onSpecial ? 0.5 : 1
        visible: !root.fullscreen

        layer.enabled: root.blur > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: root.blur
            blurMax: 32
        }

        Loader {
            asynchronous: true
            active: Config.bar.workspaces.occupiedBg

            anchors.fill: parent
            anchors.margins: Tokens.padding.extraSmall

            sourceComponent: HOccupiedBg {
                workspaces: workspaces
                occupied: root.occupied
                groupOffset: root.groupOffset
            }
        }

        RowLayout {
            id: layout

            anchors.centerIn: parent
            spacing: Math.floor(Tokens.spacing.extraSmall)

            Repeater {
                id: workspaces

                model: Config.bar.workspaces.shown

                HWorkspace {
                    activeWsId: root.activeWsId
                    occupied: root.occupied
                    groupOffset: root.groupOffset
                }
            }
        }

        Loader {
            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
            active: Config.bar.workspaces.activeIndicator

            sourceComponent: HActiveIndicator {
                activeWsId: root.activeWsId
                workspaces: workspaces
                mask: layout
                fullscreen: root.fullscreen
            }
        }

        MouseArea {
            anchors.fill: layout
            onClicked: event => {
                const ws = (layout.childAt(event.x, event.y) as HWorkspace)?.ws;
                if (!ws)
                    return;
                if (Hypr.activeWsId !== ws)
                    Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "${ws}" })` : `workspace ${ws}`);
                else
                    Hypr.dispatch(Hypr.usingLua ? 'hl.dsp.workspace.toggle_special("special")' : "togglespecialworkspace special");
            }
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: specialWs

        asynchronous: true

        anchors.fill: parent
        anchors.margins: Tokens.padding.extraSmall

        active: opacity > 0

        scale: root.onSpecial ? 1 : 0.5
        opacity: root.onSpecial ? 1 : 0

        sourceComponent: HSpecialWorkspaces {
            screen: root.screen
        }

        Behavior on scale {
            Anim {}
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }

    Behavior on blur {
        Anim {
            type: Anim.StandardSmall
        }
    }
}
