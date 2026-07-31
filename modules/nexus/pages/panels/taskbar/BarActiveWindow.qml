pragma ComponentBehavior: Bound

import QtQuick.Layouts
import Caelestia.Config
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Active window")
    isSubPage: true

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: qsTr("Compact")
            checked: Config.bar.activeWindow.compact
            onToggled: GlobalConfig.bar.activeWindow.compact = checked
        }

        ToggleRow {
            text: qsTr("Inverted")
            subtext: qsTr("Rotate the title the other way. Vertical bar only.")
            checked: Config.bar.activeWindow.inverted
            onToggled: GlobalConfig.bar.activeWindow.inverted = checked
        }

        ToggleRow {
            text: qsTr("Open popout on hover")
            subtext: qsTr("On: hovering the title opens the window details. Off: a click opens it instead.")
            checked: Config.bar.activeWindow.showOnHover
            onToggled: GlobalConfig.bar.activeWindow.showOnHover = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Window details popout")
            subtext: qsTr("Allow the active window entry to open a details popout at all")
            checked: Config.bar.popouts.activeWindow
            onToggled: GlobalConfig.bar.popouts.activeWindow = checked
        }
    }
}
