pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
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

            TextMetrics {
                id: hourMetrics

                font: root.font.build()
                text: Time.hourStr
            }
        }

        StyledText {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            text: Time.minuteStr
            font: {
                const scale = text === "11" ? 1.15 : Math.min(1.05, Math.max(hourMetrics.width, minMetrics.width) / minMetrics.width);
                return root.font.width(scale * 100).letterSpacing(scale).build();
            }
            color: root.colour

            TextMetrics {
                id: minMetrics

                font: root.font.build()
                text: Time.minuteStr
            }
        }

        Loader {
            Layout.topMargin: -parent.spacing - 4
            Layout.alignment: Qt.AlignHCenter
            asynchronous: true
            active: GlobalConfig.services.useTwelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
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
