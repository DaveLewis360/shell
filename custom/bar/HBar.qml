pragma ComponentBehavior: Bound

import "../../modules/bar/components/workspaces"
import "../../modules/bar/components"
import qs.custom
import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.bar.popouts as BarPopouts

// [fork] A vízszintes bar. Az upstream Bar.qml gyökere egy ColumnLayout; ez a
// tükörképe, RowLayout-tal.
//
// Korábban a gyökér egy Item volt, amiben a RowLayout ült, hogy a MiniDash a bar
// tetejére horgonyozható legyen. Ez két hibát okozott:
//   * a MiniDash a layout SIBLINGJE volt, ezért a layout nem tartalékolt neki
//     helyet, és a pill rárajzolt az alatta lévő elemre (jellemzően az aktív
//     ablak címére), a találat-keresés pedig az alatta lévő elemet találta meg;
//   * a HActiveWindow szélesség-számítása az upstreamből jött, ahol a `bar` MAGA
//     a layout — egy Itemnek viszont nincs `spacing`-je, így a számítás NaN-t
//     adott, amit az `int` property 0-ra alakított, és a cím elveszett.
// A MiniDash mostantól rendes bar-elem (Config.bar.entries → "miniDash"), ezért a
// wrapper Itemre nincs többé szükség, és mindkét hiba szerkezetileg megszűnik.
RowLayout {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property BarPopouts.Wrapper popouts
    required property bool fullscreen

    // [fork] upstream: vPadding (a bar függőleges, ott a padding fent/lent van)
    readonly property int hPadding: Tokens.padding.large

    // [fork] A sziget-háttér geometriájához: hol végződik a bal oldali rész (az
    // első fillWidth elem után), és hol van a workspaces blokk.
    property real rightPartX: {
        let xVal = width; // ha nincs fillWidth elem, a jobb szél
        for (let i = repeater.count - 1; i >= 0; i--) {
            const entry = repeater.itemAt(i) as EntryWrapper;
            if (entry?.modelData) {
                const entryId = entry.modelData.id;
                if (entryId === "activeWindow" || entryId === "spacer") {
                    xVal = entry.x + entry.width;
                    break;
                }
            }
        }
        return xVal;
    }

    property real workspacesX: {
        for (let i = 0; i < repeater.count; i++) {
            const entry = repeater.itemAt(i) as EntryWrapper;
            if (entry?.modelData?.id === "workspaces")
                return entry.x;
        }
        return 0;
    }

    property real workspacesWidth: {
        for (let i = 0; i < repeater.count; i++) {
            const entry = repeater.itemAt(i) as EntryWrapper;
            if (entry?.modelData?.id === "workspaces")
                return entry.width;
        }
        return 0;
    }

    function closeTray(): void {
        if (!Config.bar.tray.compact)
            return;

        for (let i = 0; i < repeater.count; i++) {
            const tray = (repeater.itemAt(i) as EntryWrapper).item as HTray;
            if (tray)
                tray.expanded = false;
        }
    }

    // [fork] Vízszintes bar: a találatot x mentén keressük, a popout középpontja
    // is x koordináta (upstreamben y).
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
            } else {
                popouts.hasCurrent = false;
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
        } else {
            popouts.hasCurrent = false;
        }
    }

    // [fork] Vízszintes bar: a hangerő/fényerő felezés x mentén történik.
    function handleWheel(x: real, angleDelta: point): void {
        const ch = childAt(x, height / 2) as EntryWrapper;
        if (ch?.entryId === "workspaces" && Config.bar.scrollActions.workspaces) {
            // Workspace scroll
            const mon = (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.workspace.toggle_special("${specialWs.slice(8)}")` : `togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (GlobalConfig.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ workspace = "r${angleDelta.y > 0 ? "-" : "+"}1" })` : `workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
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

    spacing: Tokens.spacing.medium

    Repeater {
        id: repeater

        model: ScriptModel {
            // [fork] A "miniDash" bejegyzést a fork saját kapcsolója is kapuzza,
            // hogy egyetlen, jól látható ki/be váltó legyen a beállításokban.
            values: root.Config.bar.entries.filter(e => (e.enabled ?? true) && (e.id !== "miniDash" || ExtrasConfig.miniDash))
        }

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: EntryWrapper {
                    Layout.fillWidth: true // [fork] upstream: fillHeight
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
                    Layout.fillWidth: true // [fork]
                    HActiveWindow {
                        objectName: "taskbarActiveWindow"
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            // [fork] A MiniDash pill. Csak a vízszintes barnak van rá delegate-je;
            // az upstream vertikális Bar.qml-ben a DelegateChooser nem talál
            // egyezést, ezért ott nem jön létre elem, és a bejegyzés nem foglal
            // helyet.
            DelegateChoice {
                roleValue: "miniDash"
                delegate: EntryWrapper {
                    MiniDash {
                        objectName: "taskbarMiniDash"
                        screenState: root.screenState
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
                    HPower {
                        objectName: "taskbarPowerButton"
                        screenState: root.screenState
                    }
                }
            }
        }
    }

    component EntryWrapper: Item {
        required property var modelData
        required property int index
        default property Item item
        readonly property string entryId: modelData.id

        // [fork] Vízszintes bar: a szél-padding bal/jobb oldalra kerül,
        // és az igazítás vertikális. Upstreamben top/bottom + AlignHCenter.
        Layout.leftMargin: index === 0 ? root.hPadding : 0
        Layout.rightMargin: index === repeater.count - 1 ? root.hPadding : 0
        Layout.alignment: Qt.AlignVCenter

        implicitWidth: item?.implicitWidth ?? 0
        implicitHeight: item?.implicitHeight ?? 0

        children: item
    }
}
