pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.components.effects
import qs.services

// Horizontal counterpart of modules/bar/components/workspaces/ActiveIndicator.qml.
// The pill follows the active workspace's layout position (not its animated x), and
// recolours the list underneath it.
StyledRect {
    id: root

    required property ListView list
    required property int activeIdx
    property alias contentColour: colouriser.colorizationColor

    readonly property Item activeWs: {
        list.contentWidth; // Re-evaluate once delegates exist
        return list.itemAtIndex(activeIdx);
    }

    property real start
    property real end

    // Position of a delegate once the list has settled, from the widths before it
    function layoutX(idx: int): real {
        let x = 0;
        for (let i = 0; i < idx; i++)
            x += (list.itemAtIndex(i)?.width ?? 0) + list.spacing;
        return x;
    }

    function runAnim(): void {
        if (!activeWs)
            return;

        const newStart = layoutX(activeIdx);
        const goingLeft = newStart < start;
        const leadingDuration = Tokens.anim.durations.expressiveDefaultSpatial;
        const trailingDuration = leadingDuration * (Config.bar.workspaces.activeTrail ? 1.5 : 1);

        startAnim.stop();
        endAnim.stop();
        startAnim.to = newStart;
        endAnim.to = newStart + activeWs.width;
        startAnim.duration = goingLeft ? leadingDuration : trailingDuration;
        endAnim.duration = goingLeft ? trailingDuration : leadingDuration;
        startAnim.start();
        endAnim.start();
    }

    onActiveWsChanged: runAnim()
    Component.onCompleted: runAnim()

    clip: true
    x: start + list.x
    implicitWidth: end - start
    radius: Tokens.rounding.full
    color: Colours.palette.m3primary

    Anim on start {
        id: startAnim
    }

    Anim on end {
        id: endAnim
    }

    Connections {
        function onWidthChanged(): void {
            root.runAnim();
        }

        target: root.activeWs
    }

    Connections {
        function onContentWidthChanged(): void {
            root.runAnim();
        }

        target: root.list
    }

    Colouriser {
        id: colouriser

        source: root.list
        sourceColor: Colours.palette.m3onSurface
        colorizationColor: Colours.palette.m3onPrimary

        x: -parent.start
        implicitWidth: root.list.width
        implicitHeight: root.list.height

        anchors.verticalCenter: parent.verticalCenter
    }
}
