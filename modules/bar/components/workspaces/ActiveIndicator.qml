pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

StyledRect {
    id: root

    anchors.verticalCenter: parent.verticalCenter

    required property int activeWsId
    required property Repeater workspaces
    required property Item mask
    required property bool fullscreen

    readonly property int currentWsIdx: {
        let i = activeWsId - 1;
        while (i < 0)
            i += Config.bar.workspaces.shown;
        return i % Config.bar.workspaces.shown;
    }

    // X-based positioning (horizontal bar)
    readonly property real indicatorSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    property real leading: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.x ?? 0 : 0
    property real trailing: workspaces.count > 0 ? workspaces.itemAt(currentWsIdx)?.x ?? 0 : 0
    property real currentSize: indicatorSize
    property real offset: Math.min(leading, trailing)
    property real size: {
        const s = Math.abs(leading - trailing) + currentSize;
        if (Config.bar.workspaces.activeTrail && lastWs > currentWsIdx) {
            const ws = workspaces.itemAt(lastWs);
            return ws ? Math.min(ws.x + ws.size - offset, s) : 0;
        }
        return s;
    }

    property int cWs
    property int lastWs

    onCurrentWsIdxChanged: {
        lastWs = cWs;
        cWs = currentWsIdx;
    }

    clip: true
    // Loader is anchored to layout.left, so we only need the item's x position
    x: offset
    implicitHeight: Tokens.sizes.bar.innerWidth - Tokens.padding.small * 2
    implicitWidth: size
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Colouriser {
        source: root.mask
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: -parent.offset
        y: 0
        implicitWidth: root.mask.implicitWidth
        implicitHeight: root.mask.implicitHeight

        anchors.verticalCenter: parent.verticalCenter
    }

    Behavior on leading {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on trailing {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {
            duration: Tokens.anim.durations.normal * 2
        }
    }

    Behavior on currentSize {
        enabled: Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on offset {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }

    Behavior on size {
        enabled: !Config.bar.workspaces.activeTrail

        EAnim {}
    }

    component EAnim: Anim {
        easing: Tokens.anim.emphasized
    }
}
