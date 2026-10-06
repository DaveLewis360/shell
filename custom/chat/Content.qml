pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Item {
    id: root

    required property Props props
    required property ScreenState screenState

    ChatModel {
        id: transcript
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // Header: title + backend status pill
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "auto_awesome"
                color: Colours.palette.m3primary
            }

            StyledText {
                text: "Fő agent"
            }

            Item {
                Layout.fillWidth: true
            }

            StyledRect {
                implicitWidth: statusText.implicitWidth + Tokens.padding.small * 2
                implicitHeight: statusText.implicitHeight + Tokens.padding.extraSmall * 0.75

                radius: height / 2
                color: Colours.tPalette.m3surfaceContainerHighest

                StyledText {
                    id: statusText

                    anchors.centerIn: parent
                    text: "offline"
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }

        // Transcript
        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow

            StyledListView {
                id: list

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium
                spacing: Tokens.spacing.small
                clip: true

                model: transcript

                delegate: ChatMessage {}

                onCountChanged: Qt.callLater(list.positionViewAtEnd)
            }
        }

        // Input
        StyledRect {
            Layout.fillWidth: true

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow
            implicitHeight: inputRow.implicitHeight + Tokens.padding.medium * 2

            RowLayout {
                id: inputRow

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                TextArea {
                    id: input

                    Layout.fillWidth: true

                    placeholderText: qsTr("Kérdezz valamit…")
                    placeholderTextColor: Colours.palette.m3outline
                    color: Colours.palette.m3onSurface
                    wrapMode: TextArea.Wrap
                    background: null

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                            transcript.send(text);
                            clear();
                            event.accepted = true;
                        }
                    }
                }

                MaterialIcon {
                    text: "send"

                    color: input.length > 0 ? Colours.palette.m3primary : Colours.palette.m3outline

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            transcript.send(input.text);
                            input.clear();
                        }
                    }
                }
            }
        }
    }

    // Grab keyboard focus whenever the panel opens, so the input can be typed into
    Connections {
        function onChatChanged(): void {
            if (root.screenState.chat)
                input.forceActiveFocus();
        }

        target: root.screenState
    }
}
