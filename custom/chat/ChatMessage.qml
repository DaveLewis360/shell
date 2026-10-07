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

        anchors.top: parent.top
        anchors.right: root.isUser ? parent.right : undefined
        anchors.left: root.isUser ? undefined : parent.left

        implicitWidth: Math.min(msg.implicitWidth + Tokens.padding.medium * 2, root.width * 0.85)
        implicitHeight: msg.implicitHeight + Tokens.padding.small * 2

        StyledText {
            id: msg

            anchors.centerIn: parent
            width: Math.min(implicitWidth, bubble.width - Tokens.padding.medium * 2)

            text: root.text + (root.streaming ? " ▍" : "")
            textFormat: Text.MarkdownText
            color: root.isUser ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            wrapMode: Text.Wrap
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
                    color: accent ? Colours.palette.m3primary : Colours.tPalette.m3surface

                    StyledText {
                        id: permButtonLabel

                        anchors.centerIn: parent
                        text: permButton.label
                        color: permButton.accent ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
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

            StyledText {
                visible: root.answered
                text: "handled"
                color: Colours.palette.m3outline
            }
        }
    }
}
