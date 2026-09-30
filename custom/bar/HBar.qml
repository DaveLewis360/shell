pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.dashboard as Dashboard
import qs.modules.bar.components
import qs.modules.bar.popouts as BarPopouts
import qs.custom.bar.workspaces

// The top bar: upstream's modules/bar/Bar.qml laid out as a row. It reads the same
// `bar.entries` list and the same options. The logo and the power button are the
// upstream components; the others have horizontal counterparts in this directory.
RowLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen
    readonly property int hPadding: Tokens.padding.large

    // The open dashboard reaches up over the middle of the bar. It is centred on the
    // screen, like the bar, so the entries it covers fade out while it is open.
    readonly property Dashboard.Wrapper dashboard: ShellState.componentsFor(screen)?.panels?.dashboard ?? null

    // The entries between the first and the last spacer are centred on the bar, not
    // between the two sides as two equal spacers would put them. The centre gets the
    // difference between the sides as a margin towards the lighter one. (On a spacer
    // the margin would not work: a filling item with a margin takes all the spare
    // room.) Without two spacers there is no centre.
    readonly property var ids: Config.bar.entries.values.filter(e => e.enabled).map(e => e.id)
    readonly property int firstSpacer: ids.indexOf("spacer")
    readonly property int lastSpacer: ids.lastIndexOf("spacer")
    readonly property bool hasCentre: lastSpacer > firstSpacer
    property int revision // Bumped when delegates come and go, to re-measure

    readonly property int centreFirst: centreEdge(false)
    readonly property int centreLast: centreEdge(true)
    readonly property real leftWidth: sideWidth(false)
    readonly property real rightWidth: sideWidth(true)
    // Width the centre can take while it stays centred
    readonly property real centreRoom: hasCentre ? width - hPadding * 2 - Math.max(leftWidth, rightWidth) * 2 - spacing * 2 : Infinity

    // Index of the first or last centre entry that has a delegate, or -1
    function centreEdge(last: bool): int {
        revision; // Re-measure once delegates change
        if (!hasCentre)
            return -1;

        for (let n = 1; n < lastSpacer - firstSpacer; n++) {
            const i = last ? lastSpacer - n : firstSpacer + n;
            const entry = repeater.itemAt(i) as EntryWrapper;
            if (entry?.visible && entry.entryId !== "spacer")
                return i;
        }
        return -1;
    }

    // Fixed width of one side of the centre: its entries with their spacing
    function sideWidth(right: bool): real {
        revision; // Re-measure once delegates change
        if (!hasCentre)
            return 0;

        let sum = 0;
        for (let i = 0; i < repeater.count; i++) {
            if (right ? i <= lastSpacer : i >= firstSpacer)
                continue;
            const entry = repeater.itemAt(i);
            if (entry?.visible)
                sum += entry.implicitWidth + spacing;
        }
        return sum;
    }

    // What a centre entry that sizes itself to the room left (the active window
    // title) may take: the centre's room minus the other centre entries. Unlimited
    // outside the centre.
    function centreRoomFor(item: Item): real {
        revision; // Re-measure once delegates change
        if (!hasCentre)
            return Infinity;

        let own = -1;
        let others = 0;
        for (let i = firstSpacer + 1; i < lastSpacer; i++) {
            const entry = repeater.itemAt(i) as EntryWrapper;
            if (!entry?.visible)
                continue;
            if (entry.item === item)
                own = i;
            else if (entry.entryId !== "spacer")
                others += entry.implicitWidth + spacing;
        }
        return own < 0 ? Infinity : Math.max(0, centreRoom - others);
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper)?.item as HTray;
            if (tray)
                tray.expanded = false;
        }
    }

    function checkPopout(x: real): void {
        const ch = childAt(x, height / 2) as EntryWrapper;

        if (ch?.entryId !== "tray")
            closeTray();

        if (!ch) {
            popouts.hasCurrent = false;
            return;
        }

        const id = ch.entryId;
        const left = ch.x;

        if (id === "statusIcons" && Config.bar.popouts.statusIcons) {
            const items = (ch.item as HStatusIcons).items;
            const icon = items.childAt(mapToItem(items, x, 0).x, items.height / 2);
            if (icon) {
                popouts.currentName = icon.name;
                popouts.currentCenter = Qt.binding(() => icon.mapToItem(root, icon.implicitWidth / 2, 0).x);
                popouts.hasCurrent = true;
            }
        } else if (id === "tray" && Config.bar.popouts.tray) {
            const tray = ch.item as HTray;
            if (!Config.bar.tray.compact || (tray.expanded && !tray.expandIcon.contains(mapToItem(tray.expandIcon, x, tray.implicitHeight / 2)))) {
                const index = Math.floor(((x - left - tray.padding * 2 + tray.spacing) / tray.layout.implicitWidth) * tray.items.count);
                const trayItem = tray.items.itemAt(index);
                if (trayItem) {
                    popouts.currentName = `traymenu${index}`;
                    popouts.currentCenter = Qt.binding(() => trayItem.mapToItem(root, trayItem.implicitWidth / 2, 0).x);
                    popouts.hasCurrent = true;
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
        const ch = childAt(x, height / 2) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = Hypr.monitorFor(screen);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || mon.activeWorkspace?.id > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (x < screen.width / 2 && Config.bar.scrollActions.volume) {
            // Volume scroll on the left half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else if (Config.bar.scrollActions.brightness) {
            // Brightness scroll on the right half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
        }
    }

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            // Ids, not the entry objects: a config reload recreates every entry, and
            // the repeater then kept delegates of the old ids when the list changed
            values: root.ids
        }

        onItemAdded: root.revision++
        onItemRemoved: root.revision++

        DelegateChooser {
            role: "modelData"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillWidth: true
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: EntryWrapper {
                    OsIcon {
                        objectName: "taskbarLogo"
                    }
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: EntryWrapper {
                    HWorkspaces {
                        objectName: "taskbarWorkspaces"
                        screen: root.screen
                        fullscreen: root.fullscreen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: EntryWrapper {
                    HActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "miniDash"
                delegate: EntryWrapper {
                    MiniDash {
                        objectName: "taskbarMiniDash"
                        screenState: root.screenState
                        bar: root
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: EntryWrapper {
                    HTray {
                        objectName: "taskbarTray"
                    }
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: EntryWrapper {
                    HClock {
                        objectName: "taskbarClock"
                    }
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: EntryWrapper {
                    HStatusIcons {
                        objectName: "taskbarStatusIcons"
                    }
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: EntryWrapper {
                    Power {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property string modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData

        Layout.leftMargin: (index === 0 ? root.hPadding : 0) + (index === root.centreFirst ? Math.max(0, root.rightWidth - root.leftWidth) : 0)
        Layout.rightMargin: (index === repeater.count - 1 ? root.hPadding : 0) + (index === root.centreLast ? Math.max(0, root.leftWidth - root.rightWidth) : 0)
        Layout.alignment: Qt.AlignVCenter

        readonly property bool underDashboard: {
            const dash = root.dashboard;
            if (!dash || dash.width <= 0)
                return false;
            const left = (root.width - dash.width) / 2;
            return x < left + dash.width && x + width > left;
        }

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0
        opacity: underDashboard ? root.dashboard.offsetScale : 1

        children: item
    }
}
