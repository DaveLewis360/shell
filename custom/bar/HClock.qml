pragma ComponentBehavior: Bound

import "../../modules/bar/components"
import "../../modules/bar/components/workspaces"
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

        Loader {
            asynchronous: true
            anchors.verticalCenter: parent.verticalCenter
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: Column {
                spacing: -2

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.format("ddd")
                    font: Tokens.font.body.builders.small.scale(0.8).build()
                    color: root.colour
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Time.format("d")
                    font: Tokens.font.body.builders.small.scale(1.1).build()
                    color: root.colour
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            horizontalAlignment: StyledText.AlignHCenter
            text: Time.format(GlobalConfig.services.useTwelveHourClock ? "hh:mm A" : "hh:mm")
            font: Tokens.font.mono.small
            color: root.colour
        }
    }
}
