pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import qs.components
import qs.services

StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Tokens.padding.small

    implicitWidth: layout.implicitWidth + root.padding * 2
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: "transparent"

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Loader {
            asynchronous: true
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

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(GlobalConfig.services.useTwelveHourClock ? "hh:mm A" : "hh:mm")
            font.pointSize: Tokens.font.size.smaller
            font.family: Tokens.font.family.mono
            color: root.colour
        }
    }
}
