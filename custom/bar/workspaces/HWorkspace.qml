pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

// Horizontal counterpart of modules/bar/components/workspaces/Workspace.qml, as a
// ListView delegate: the indicator, then the window icons to its right. Colours,
// labels, shapes and icon rules are unchanged from upstream.
Item {
    id: root

    required property var modelData
    required property int index
    required property int activeWsId
    required property int ws
    required property HyprlandMonitor monitor

    required property int displayType
    required property bool showWindows
    required property var iconRules
    property string activeLabel
    property string occupiedLabel
    property string label

    // Special workspaces are identified by name: Hyprland 0.57 no longer gives
    // them a numeric id (Quickshell reports -1 for all of them). Empty for
    // numbered workspaces, which keep using ws/activeWsId.
    property string specialName
    property string activeSpecialName
    readonly property HyprlandWorkspace wsObject: specialName ? (Hypr.workspaces.values.find(w => w.name === specialName) ?? null) : (Hypr.workspaces.values.find(w => w.id === ws) ?? null)

    readonly property list<HyprlandToplevel> toplevels: specialName ? Hypr.toplevelsForWsName(specialName, GlobalConfig.bar.workspaces.ignoredTags) : Hypr.toplevelsForWs(ws, GlobalConfig.bar.workspaces.ignoredTags)
    readonly property bool isOccupied: toplevels.length > 0
    readonly property bool hasWindows: isOccupied && showWindows && Config.bar.workspaces.maxWindowIcons > 0
    readonly property bool focused: specialName ? activeSpecialName === specialName : activeWsId === ws
    readonly property list<int> focusedShapeList: [MaterialShape.Slanted, MaterialShape.Oval, MaterialShape.Pill, MaterialShape.Triangle, MaterialShape.Arrow, MaterialShape.Diamond, MaterialShape.Pentagon, MaterialShape.Gem, MaterialShape.VerySunny, MaterialShape.Sunny, MaterialShape.Cookie4Sided, MaterialShape.Cookie6Sided, MaterialShape.Cookie7Sided, MaterialShape.Cookie9Sided, MaterialShape.Cookie12Sided, MaterialShape.Clover4Leaf, MaterialShape.SoftBurst, MaterialShape.Ghostish]
    readonly property int indicatorSize: Tokens.sizes.bar.innerWidth - Tokens.padding.small

    property color offMonitorColour: Colours.palette.m3outlineVariant
    readonly property bool onOtherMonitor: {
        if (Config.bar.workspaces.perMonitor)
            return false;
        const mon = wsObject?.monitor;
        return !!(mon && mon !== monitor);
    }
    readonly property color fgColour: {
        if (onOtherMonitor)
            return offMonitorColour;
        if (focused || isOccupied || Config.bar.workspaces.occupiedBg)
            return Colours.palette.m3onSurface;
        return Colours.layer(Colours.palette.m3outlineVariant, 2);
    }

    // Final layout width, unanimated: the horizontal equivalent of upstream's
    // LazyListView.preferredHeight. Scroll and indicator math measures this,
    // never the animated `width`. Appear animation is opacity-only (ListView
    // add/remove Transitions), so settled geometry is available immediately.
    readonly property real preferredWidth: layout.implicitWidth + (hasWindows ? Tokens.padding.extraSmall : 0)

    function updateShape(): void {
        const shape = indicator.item as MaterialShape;
        if (!shape)
            return;

        if (focused)
            shape.shape = focusedShapeList[Math.floor(Math.random() * focusedShapeList.length)];
        else
            shape.shape = Qt.binding(() => isOccupied ? MaterialShape.Square : MaterialShape.Circle);
    }

    implicitWidth: preferredWidth
    implicitHeight: indicatorSize
    height: ListView.view?.height ?? implicitHeight

    onFocusedChanged: updateShape()
    Component.onCompleted: updateShape()

    Component {
        id: shapeComponent

        MaterialShape {
            implicitSize: root.indicatorSize

            color: root.fgColour
            scale: root.focused ? 2 / 3 : root.isOccupied ? 1 / 3 : 1 / 4

            animationEasing: Tokens.anim.expressiveDefaultSpatial
            animationDuration: Tokens.anim.durations.expressiveDefaultSpatial * Tokens.anim.durations.scale

            Behavior on color {
                CAnim {}
            }

            Behavior on scale {
                Anim {}
            }
        }
    }

    Component {
        id: textComponent

        StyledText {
            animate: true
            text: {
                if (root.focused) {
                    const label = root.activeLabel;
                    if (label)
                        return label;
                }

                if (root.focused || root.isOccupied) {
                    const label = root.occupiedLabel;
                    if (label)
                        return label;
                }

                const label = root.label;
                if (label)
                    return label;

                const ws = root.wsObject;
                const wsName = !ws || ws.name === String(root.ws) ? root.ws : Hypr.trimWsName(ws.name)[0];

                const capitalisation = Config.bar.workspaces.capitalisation;
                if (capitalisation === BarWorkspaceCapitalisation.Upper)
                    return String(wsName).toUpperCase();
                else if (capitalisation === BarWorkspaceCapitalisation.Lower)
                    return String(wsName).toLowerCase();
                return wsName;
            }
            color: root.fgColour
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            font.family: Tokens.font.workspaces
        }
    }

    Component {
        id: iconComponent

        MaterialIcon {
            fill: 1
            grade: 25
            text: iconCacher.icon
            color: root.fgColour
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter

            WsIconCacher {
                id: iconCacher
            }
        }
    }

    Component {
        id: iconLoaderComponent

        Loader {
            sourceComponent: loaderIconCacher.icon ? iconComponent : textComponent

            WsIconCacher {
                id: loaderIconCacher
            }
        }
    }

    RowLayout {
        id: layout

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        spacing: 0

        Loader {
            id: indicator

            Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
            Layout.preferredWidth: root.indicatorSize
            sourceComponent: {
                if (root.displayType === BarWorkspaceDisplay.Icons)
                    return iconLoaderComponent;
                if (root.displayType === BarWorkspaceDisplay.Text)
                    return textComponent;
                return shapeComponent;
            }

            onItemChanged: root.updateShape()
        }

        Loader {
            id: windows

            asynchronous: true

            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: -Tokens.spacing.extraSmall / 2
            Layout.preferredWidth: root.hasWindows ? (item as Row)?.implicitWidth ?? 0 : 0

            visible: active
            active: root.showWindows && Config.bar.workspaces.maxWindowIcons > 0

            sourceComponent: Row {
                clip: true

                Repeater {
                    model: ScriptModel {
                        values: {
                            const windows = root.toplevels;
                            const maxIcons = root.Config.bar.workspaces.maxWindowIcons;
                            return maxIcons > 0 ? windows.slice(0, maxIcons) : windows;
                        }
                    }

                    MaterialIcon {
                        required property var modelData

                        grade: 0
                        text: Icons.getAppCategoryIcon(modelData.lastIpcObject.class, "terminal")
                        color: root.onOtherMonitor ? root.offMonitorColour : Colours.palette.m3onSurfaceVariant
                    }
                }
            }
        }
    }

    component WsIconCacher: QtObject {
        id: cacher

        property string name
        readonly property string icon: Icons.matchIconRuleList(Hypr.trimWsName(name), root.iconRules)
        readonly property HyprlandWorkspace wsObj: root.wsObject

        readonly property Connections conn: Connections {
            function onNameChanged(): void {
                cacher.updateName();
            }

            target: cacher.wsObj
        }

        function updateName(): void {
            if (wsObj)
                name = wsObj.name;
        }

        onWsObjChanged: updateName()
        Component.onCompleted: updateName()
    }
}
