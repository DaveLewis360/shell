import "../effects"
import QtQuick
import QtQuick.Templates
import Caelestia.Config
import qs.components
import qs.services

Slider {
    id: root

    required property string icon
    property real oldValue
    property bool initialized

    orientation: Qt.Vertical

    background: StyledRect {
        color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
        radius: Tokens.rounding.full

        StyledRect {
            anchors.left: parent.left
            anchors.right: parent.right

            y: root.handle.y
            implicitHeight: parent.height - y

            color: Colours.palette.m3secondary
            radius: parent.radius
        }
    }

    handle: Item {
        id: handle

        property bool moving

        y: root.visualPosition * (root.availableHeight - height)
        implicitWidth: root.width
        implicitHeight: root.width

        Elevation {
            anchors.fill: parent
            radius: rect.radius
            level: handleInteraction.containsMouse ? 2 : 1
        }

        StyledRect {
            id: rect

            anchors.fill: parent

            color: Colours.palette.m3inverseSurface
            radius: Tokens.rounding.full

            MouseArea {
                id: handleInteraction

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.NoButton
            }

            Item {
                id: iconWrapper
                anchors.centerIn: parent

                property bool moving: handle.moving

                function update(): void {
                    icon.animate = !moving;
                    icon.visible = !moving;
                    number.visible = moving;
                }

                onMovingChanged: anim.restart()

                SequentialAnimation {
                    id: anim

                    Anim {
                        target: iconWrapper
                        property: "scale"
                        to: 0
                        duration: Tokens.anim.durations.normal / 2
                        easing: Tokens.anim.standardAccel
                    }
                    ScriptAction {
                        script: iconWrapper.update()
                    }
                    Anim {
                        target: iconWrapper
                        property: "scale"
                        to: 1
                        duration: Tokens.anim.durations.normal / 2
                        easing: Tokens.anim.standardDecel
                    }
                }

                MaterialIcon {
                    id: icon
                    text: root.icon
                    color: Colours.palette.m3inverseOnSurface
                    anchors.centerIn: parent
                    fontStyle.pointSize: Tokens.font.size.larger
                    visible: true
                }

                StyledText {
                    id: number
                    text: Math.round(root.value * 100)
                    color: Colours.palette.m3inverseOnSurface
                    anchors.centerIn: parent
                    font.family: Tokens.font.family.sans
                    font.pointSize: Tokens.font.size.small
                    visible: false
                }
            }
        }
    }

    onPressedChanged: handle.moving = pressed

    onValueChanged: {
        if (!initialized) {
            initialized = true;
            return;
        }
        if (Math.abs(value - oldValue) < 0.01)
            return;
        oldValue = value;
        handle.moving = true;
        stateChangeDelay.restart();
    }

    Timer {
        id: stateChangeDelay

        interval: 500
        onTriggered: {
            if (!root.pressed)
                handle.moving = false;
        }
    }

    Behavior on value {
        Anim {
            type: Anim.StandardLarge
        }
    }
}
