pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property string sender
    required property string text
    required property string kind
    required property string permId
    required property bool answered
    required property string answeredResponse
    required property bool streaming
    required property string title
    required property string detail
    required property int index

    property var agentClient

    readonly property bool isUser: sender === "user"

    width: ListView.view?.width ?? 0
    implicitHeight: kind === "permission" ? permCard.height : bubble.height

    // Regular chat message
    StyledRect {
        id: bubble

        visible: root.kind === "msg"
        radius: Tokens.rounding.medium
        color: root.isUser ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHighest
        opacity: root.streaming ? 0.75 : 1
        clip: true

        anchors.top: parent.top
        anchors.right: root.isUser ? parent.right : undefined
        anchors.left: root.isUser ? undefined : parent.left

        implicitWidth: Math.min(msg.implicitWidth + Tokens.padding.medium * 2, root.width * 0.85)
        implicitHeight: msg.implicitHeight + Tokens.padding.small * 2

        // Wide non-wrapping markdown (tables, code fences) used to bleed out
        // of the bubble and got cut by the list edges. The text still wraps at
        // the bubble width like before, but anything wider is now pannable
        // sideways inside the bubble instead of running off the panel.
        Flickable {
            id: msgFlick

            anchors.fill: parent
            anchors.leftMargin: Tokens.padding.medium
            anchors.rightMargin: Tokens.padding.medium
            anchors.topMargin: Tokens.padding.small
            anchors.bottomMargin: Tokens.padding.small
            contentWidth: Math.max(width, msg.implicitWidth)
            contentHeight: height
            interactive: contentWidth > width + 1
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            StyledText {
                id: msg

                x: 0
                y: 0
                width: msgFlick.width

                text: root.text + (root.streaming ? " ▍" : "")
                textFormat: Text.MarkdownText
                color: root.isUser ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                wrapMode: Text.Wrap
            }
        }
    }

    // Permission request card
    StyledRect {
        id: permCard

        visible: root.kind === "permission"
        width: parent.width
        radius: Tokens.rounding.medium
        color: Colours.tPalette.m3surfaceContainerHighest

        implicitHeight: permLayout.implicitHeight + Tokens.padding.small * 2

        ColumnLayout {
            id: permLayout

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.small
            spacing: Tokens.spacing.small

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                MaterialIcon {
                    text: "gpp_maybe"
                    color: Colours.palette.m3primary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    color: Colours.palette.m3onSurface
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.detail.length > 0
                text: root.detail
                textFormat: Text.PlainText
                font.family: "monospace"
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideRight
                maximumLineCount: 4
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                visible: !root.answered
                spacing: Tokens.spacing.small

                component PermButton: StyledRect {
                    id: permButton

                    property string label
                    property string response
                    property bool accent

                    signal clicked()

                    Layout.fillWidth: true
                    implicitHeight: permButtonLabel.implicitHeight + Tokens.padding.extraSmall * 2
                    radius: Tokens.rounding.small

                    // Visual feedback: hover brightens, press deepens. The
                    // states live on permMouse - unqualified pressed/
                    // containsMouse would not resolve outside a MouseArea.
                    color: {
                        const base = accent ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHighest;
                        return permMouse.pressed ? Qt.darker(base, 1.12) : permMouse.containsMouse ? Qt.lighter(base, 1.12) : base;
                    }

                    opacity: permMouse.pressed ? 0.92 : 1

                    Behavior on opacity {
                        Anim {
                            type: Anim.FastEffects
                        }
                    }

                    StyledText {
                        id: permButtonLabel

                        anchors.centerIn: parent
                        text: permButton.label
                        color: permButton.accent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    }

                    MouseArea {
                        id: permMouse

                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onClicked: permButton.clicked()
                    }
                }

                PermButton {
                    label: "Approve"
                    response: "once"
                    accent: true

                    onClicked: root.agentClient?.respondPermission(root.permId, response)
                }

                PermButton {
                    label: "Always"
                    response: "always"

                    onClicked: root.agentClient?.respondPermission(root.permId, response)
                }

                PermButton {
                    label: "Reject"
                    response: "reject"

                    onClicked: root.agentClient?.respondPermission(root.permId, response)
                }
            }

            // Resolved state (Cline/Roo-style): the ask collapses into a
            // one-line receipt showing what was chosen, buttons gone.
            RowLayout {
                visible: root.answered
                spacing: Tokens.spacing.extraSmall

                MaterialIcon {
                    text: root.answeredResponse === "reject" ? "cancel" : root.answeredResponse === "always" ? "done_all" : "check_circle"
                    color: root.answeredResponse === "reject" ? Colours.palette.m3error : Colours.palette.m3primary
                }

                StyledText {
                    text: root.answeredResponse === "reject" ? qsTr("Rejected") : root.answeredResponse === "always" ? qsTr("Always approved") : qsTr("Approved")
                    color: root.answeredResponse === "reject" ? Colours.palette.m3error : Colours.palette.m3primary
                }
            }
        }
    }
}
