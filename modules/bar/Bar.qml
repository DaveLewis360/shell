pragma ComponentBehavior: Bound

import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int hPadding: Tokens.padding.large
    property real trayX: 0

    // Export MiniDash width for the background morphing logic
    property alias pillWidth: miniDash.pillWidth

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const loader = repeater.itemAt(i) as WrappedLoader;
            if (loader?.enabled && loader.id === "tray") {
                (loader.item as Tray).expanded = false;
            }
        }
    }

    function checkPopout(x: real): void {
        const ch = layout.childAt(x, layout.height / 2) as WrappedLoader;

        if (ch?.id !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.id;
        const left = ch.x;
        const item = ch.item;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as StatusIcons).items;
            const icon = items.childAt(items.mapFromItem(root, x, 0).x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as Tray;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(tray.expandIcon.mapFromItem(root, x, root.height / 2)))) {
                const localX = tray.layout.mapFromItem(root, x, 0).x;
                const trayItem = tray.layout.childAt(localX, tray.layout.height / 2);
                if (trayItem) {
                    let index = -1;
                    for (let i = 0; i < tray.items.count; i++) {
                        if (tray.items.itemAt(i) === trayItem) {
                            index = i;
                            break;
                        }
                    }

                    if (index !== -1) {
                        popouts.currentName = `traymenu${index}`;
                        popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
                        popouts.hasCurrent = true;
                    } else {
                        popouts.hasCurrent = false;
                    }
                } else {
                    popouts.hasCurrent = false;
                }
            } else {
                popouts.hasCurrent = false;
                tray.expanded = true;
            }
        } else if (id === "activeWindow" && Config.bar.popouts.activeWindow && Config.bar.activeWindow.showOnHover) {
            popouts.currentName = id.toLowerCase();
            popouts.currentCenter = (ch.item as Item).mapToItem(root, (ch.item as Item).implicitWidth / 2, 0).x ?? 0;
            popouts.hasCurrent = true;
        }
    }

    function handleWheel(x: real, angleDelta: point): void {
        const ch = layout.childAt(x, layout.height / 2) as WrappedLoader;
        if (ch?.id === "workspaces" && Config.bar.scrollActions.workspaces) {
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (x < screen.width / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on left half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on right half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    // Morphing glass background starting from tray position
    StyledRect {
        z: -1
        x: Math.max(0, root.trayX - layout.spacing)
        width: root.width - x
        height: root.height
        color: Colours.glassBackground
        radius: Config.border.rounding
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        spacing: Tokens.spacing.normal

        Repeater {
            id: repeater

            model: Config.bar.entries

            DelegateChooser {
                role: "id"

                DelegateChoice {
                    roleValue: "spacer"
                    delegate: WrappedLoader {
                        Layout.fillWidth: enabled
                    }
                }
                DelegateChoice {
                    roleValue: "logo"
                    delegate: WrappedLoader {
                        sourceComponent: OsIcon {}
                    }
                }
                DelegateChoice {
                    roleValue: "workspaces"
                    delegate: WrappedLoader {
                        sourceComponent: Workspaces {
                            screen: root.screen
                            fullscreen: root.fullscreen
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "activeWindow"
                    delegate: WrappedLoader {
                        Layout.fillHeight: true
                        visible: !root.fullscreen
                        sourceComponent: ActiveWindow {
                            bar: root
                            monitor: Brightness.getMonitorForScreen(root.screen)
                        }
                    }
                }
                DelegateChoice {
                    roleValue: "tray"
                    delegate: WrappedLoader {
                        visible: !root.fullscreen
                        sourceComponent: Tray {}
                    }
                }
                DelegateChoice {
                    roleValue: "clock"
                    delegate: WrappedLoader {
                        visible: !root.fullscreen
                        sourceComponent: Clock {}
                    }
                }
                DelegateChoice {
                    roleValue: "statusIcons"
                    delegate: WrappedLoader {
                        visible: !root.fullscreen
                        sourceComponent: StatusIcons {}
                    }
                }
                DelegateChoice {
                    roleValue: "power"
                    delegate: WrappedLoader {
                        sourceComponent: Power {
                            visibilities: root.visibilities
                        }
                    }
                }
            }
        }
    }

    // Mini Dashboard Pill, anchored to the top center
    MiniDash {
        id: miniDash
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        visibilities: root.visibilities
    }

    component WrappedLoader: Loader {
        required enabled
        required property string id
        required property int index

        function findFirstEnabled(): Item {
            const count = repeater.count;
            for (let i = 0; i < count; i++) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        function findLastEnabled(): Item {
            for (let i = repeater.count - 1; i >= 0; i--) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        asynchronous: true
        Layout.alignment: Qt.AlignVCenter

        // Padding for first and last enabled components
        Layout.leftMargin: findFirstEnabled() === this ? root.hPadding : 0
        Layout.rightMargin: findLastEnabled() === this ? root.hPadding : 0

        visible: enabled
        active: enabled

        onXChanged: if (id === "tray") root.trayX = x
        Component.onCompleted: if (id === "tray") root.trayX = x
    }
}
