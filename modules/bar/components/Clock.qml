pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

Row {
    id: root

    readonly property color colour: Colours.palette.m3tertiary

    spacing: Tokens.spacing.small

    Loader {
        anchors.verticalCenter: parent.verticalCenter

        active: Config.bar.clock.showIcon
        visible: active

        sourceComponent: MaterialIcon {
            text: "calendar_month"
            color: root.colour
        }
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter

        visible: Config.bar.clock.showDate

        text: Time.format("MMM d")
        font.pointSize: Tokens.font.size.smaller
        font.family: Tokens.font.family.sans
        color: root.colour
        opacity: 0.7
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        visible: Config.bar.clock.showDate
        width: 1
        height: parent.height * 0.5
        color: root.colour
        opacity: 0.3
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter

        text: Time.format(GlobalConfig.services.useTwelveHourClock ? "hh:mm A" : "hh:mm")
        font.pointSize: Tokens.font.size.smaller
        font.family: Tokens.font.family.mono
        color: root.colour
    }
}
