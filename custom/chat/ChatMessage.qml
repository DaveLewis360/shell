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

    readonly property bool isUser: sender === "user"

    width: ListView.view?.width ?? 0
    implicitHeight: bubble.height

    StyledRect {
        id: bubble

        radius: Tokens.rounding.medium
        color: root.isUser ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHighest

        anchors.top: parent.top
        anchors.right: root.isUser ? parent.right : undefined
        anchors.left: root.isUser ? undefined : parent.left

        implicitWidth: Math.min(msg.implicitWidth + Tokens.padding.medium * 2, root.width * 0.85)
        implicitHeight: msg.implicitHeight + Tokens.padding.small * 2

        StyledText {
            id: msg

            anchors.centerIn: parent
            width: Math.min(implicitWidth, bubble.width - Tokens.padding.medium * 2)

            text: root.text
            textFormat: Text.MarkdownText
            color: root.isUser ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
            wrapMode: Text.Wrap
        }
    }
}
