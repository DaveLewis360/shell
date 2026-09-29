pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Horizontal counterpart of modules/bar/components/Clock.qml, with the same options,
// fonts and colours. Along a row the parts sit side by side: the icon, the date
// (weekday over day, then the divider) and the time on one line.
StyledRect {
    id: root

    readonly property color colour: Colours.palette.m3tertiary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    readonly property var font: Tokens.font.body.builders.small.scale(1.1)

    implicitWidth: layout.implicitWidth + root.padding * 2
    implicitHeight: Tokens.sizes.bar.innerWidth

    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            asynchronous: true
            active: Config.bar.clock.showIcon
            visible: active

            sourceComponent: MaterialIcon {
                text: "calendar_month"
                color: root.colour
            }
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            asynchronous: true
            active: Config.bar.clock.showDate
            visible: active

            sourceComponent: Row {
                spacing: Tokens.spacing.small

                Column {
                    id: date

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: -4

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Time.format("ddd")
                        font: Tokens.font.body.builders.small.scale(0.9).build()
                        color: root.colour
                    }

                    StyledText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Time.format("d")
                        font: root.font.scale(1.1).build()
                        color: root.colour
                    }
                }

                StyledRect {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: 1
                    implicitHeight: date.implicitHeight - Tokens.padding.small
                    color: Colours.palette.m3outlineVariant
                }
            }
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Config.bar.clock.showSeconds ? `${Time.hourStr}:${Time.minuteStr}:${Time.format("ss")}` : `${Time.hourStr}:${Time.minuteStr}`
            font: root.font.build()
            color: root.colour
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            asynchronous: true
            active: Units.twelveHourClock
            visible: active

            sourceComponent: StyledText {
                text: Time.amPmStr.toLowerCase()
                font: Tokens.font.body.builders.small.scale(0.9).build()
                color: root.colour
            }
        }
    }
}
