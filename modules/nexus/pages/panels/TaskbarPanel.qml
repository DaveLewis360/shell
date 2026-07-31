pragma ComponentBehavior: Bound

import qs.custom
import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Taskbar")
    isSubPage: true

    // [fork] Az elemek jelenléte a bar.entries listából jön; ez a lista a
    // sorrendet IS adja, ezért nem lehet egyszerű bool property-ként kezelni.
    // Ezek a segédek egyetlen bejegyzés `enabled` mezőjét írják át, a többit és a
    // sorrendet érintetlenül hagyva — így az aktív ablak és a MiniDash egymással
    // felcserélhető anélkül, hogy kézzel kellene JSON-t szerkeszteni.
    function entryEnabled(id: string): bool {
        const e = Config.bar.entries.find(x => x.id === id);
        return e ? (e.enabled ?? true) : false;
    }

    function setEntryEnabled(id: string, on: bool): void {
        GlobalConfig.bar.entries = Config.bar.entries.map(e => e.id === id ? ({
                    id: e.id,
                    enabled: on
                }) : e);
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Layout — [fork] a vízszintes bar váltója
        SectionHeader {
            first: true
            text: qsTr("Layout")
        }

        ToggleRow {
            first: true
            text: qsTr("Horizontal bar")
            subtext: qsTr("Place the bar along the top edge instead of the left")
            checked: ExtrasConfig.horizontalBar
            onToggled: ExtrasConfig.setValue("bar", "horizontal", checked)
        }

        // [fork] Korábban ezt nem lehetett külön kérni: a vízszintes váltó
        // döntötte el mellékhatásként.
        ToggleRow {
            text: qsTr("Island background")
            subtext: qsTr("Draw the bar as separate rounded blocks with gaps, instead of one continuous surface. Horizontal bar only — the vertical bar is always continuous.")
            checked: ExtrasConfig.barIslands
            onToggled: ExtrasConfig.setValue("bar", "islands", checked)
        }

        // [fork] A középső sávban egyszerre egy elem lehet, ezért a MiniDash
        // kapcsolója dönti el, melyik: bekapcsolva kiszorítja az aktív ablak címét.
        ToggleRow {
            text: qsTr("Active window title")
            subtext: qsTr("Show the focused window's icon and title in the centre of the bar. The mini dashboard takes this slot when enabled.")
            checked: root.entryEnabled("activeWindow")
            onToggled: root.setEntryEnabled("activeWindow", checked)
        }

        ToggleRow {
            last: true
            text: qsTr("Mini dashboard")
            subtext: qsTr("System metrics and media controls as a pill, replacing the active window title in the centre. Horizontal bar only.")
            checked: ExtrasConfig.miniDash
            onToggled: ExtrasConfig.setValue("miniDash", "enabled", checked)
        }

        // Behaviour
        SectionHeader {
            text: qsTr("Behaviour")
        }

        ToggleRow {
            first: true
            text: qsTr("Persistent")
            subtext: qsTr("Keep the bar visible at all times")
            checked: Config.bar.persistent
            onToggled: GlobalConfig.bar.persistent = checked
        }

        ToggleRow {
            text: qsTr("Show on hover")
            subtext: qsTr("Reveal the bar when the cursor reaches the screen edge")
            checked: Config.bar.showOnHover
            onToggled: GlobalConfig.bar.showOnHover = checked
        }

        StepperRow {
            last: true
            label: qsTr("Drag threshold")
            subtext: qsTr("Pixels dragged before the bar reveals")
            value: Config.bar.dragThreshold
            from: 0
            to: 200
            stepSize: 5
            onMoved: v => GlobalConfig.bar.dragThreshold = v
        }

        // Components
        SectionHeader {
            text: qsTr("Components")
        }

        NavRow {
            first: true
            icon: "workspaces"
            text: qsTr("Workspaces")
            subtext: qsTr("Indicators, window icons")
            onClicked: root.nState.openSubPage(6)
        }

        NavRow {
            icon: "web_asset"
            text: qsTr("Active window")
            subtext: qsTr("Title display, popout")
            onClicked: root.nState.openSubPage(7)
        }

        NavRow {
            icon: "widgets"
            text: qsTr("Tray")
            subtext: qsTr("System tray icons")
            onClicked: root.nState.openSubPage(8)
        }

        NavRow {
            icon: "signal_cellular_alt"
            text: qsTr("Status icons")
            subtext: qsTr("Visible indicators")
            onClicked: root.nState.openSubPage(9)
        }

        NavRow {
            last: true
            icon: "schedule"
            text: qsTr("Clock")
            subtext: qsTr("Date, icon, background")
            onClicked: root.nState.openSubPage(10)
        }

        // Scroll actions
        SectionHeader {
            text: qsTr("Scroll actions")
        }

        ToggleRow {
            first: true
            text: qsTr("Workspaces")
            subtext: qsTr("Scroll over the workspace indicator to switch workspaces")
            checked: Config.bar.scrollActions.workspaces
            onToggled: GlobalConfig.bar.scrollActions.workspaces = checked
        }

        ToggleRow {
            text: qsTr("Volume")
            subtext: qsTr("Scroll on the top half of the bar to adjust volume")
            checked: Config.bar.scrollActions.volume
            onToggled: GlobalConfig.bar.scrollActions.volume = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Brightness")
            subtext: qsTr("Scroll on the bottom half of the bar to adjust brightness")
            checked: Config.bar.scrollActions.brightness
            onToggled: GlobalConfig.bar.scrollActions.brightness = checked
        }
    }
}
