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

    readonly property bool busy: busyState

    property bool busyState: false

    AgentClient {
        id: client

        onNewMessage: (sender, text) => root.pushEntry({
            sender: sender,
            text: text
        })

        onAssistantText: text => {
            root.busyState = true;
            const last = transcript.count - 1;
            if (last >= 0 && transcript.get(last).sender === "assistant" && transcript.get(last).streaming) {
                transcript.setProperty(last, "text", text);
            } else {
                root.pushEntry({
                    sender: "assistant",
                    text: text,
                    streaming: true
                });
            }
            list.positionViewAtEnd();
        }

        onMessageDone: {
            const last = transcript.count - 1;
            if (last >= 0)
                transcript.setProperty(last, "streaming", false);
            root.busyState = false;
        }

        onPermissionRequested: (id, title, detail) => root.pushEntry({
            kind: "permission",
            permId: id,
            title: title,
            detail: detail
        })
    }

    ListModel {
        id: transcript
    }

    function pushEntry(props: var): void {
        transcript.append(Object.assign({
            sender: "",
            text: "",
            kind: "msg",
            permId: "",
            answered: false,
            streaming: false,
            title: "",
            detail: ""
        }, props));
    }

    function respond(permId: string, response: string, index: int): void {
        client.respondPermission(permId, response);
        transcript.setProperty(index, "answered", true);
    }

    function send(): void {
        const text = input.text.trim();
        if (text.length === 0 || client.state !== "online")
            return;

        root.pushEntry({
            sender: "user",
            text: text
        });
        client.send(text);
        input.clear();
        root.busyState = true;
        list.positionViewAtEnd();
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // Header: title, status, session actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "auto_awesome"
                color: Colours.palette.m3primary
            }

            StyledText {
                text: "Chief agent"
            }

            Item {
                Layout.fillWidth: true
            }

            // Status pill
            StyledRect {
                radius: height / 2
                implicitWidth: statusText.implicitWidth + Tokens.padding.small * 2
                implicitHeight: statusText.implicitHeight + Tokens.padding.extraSmall * 0.75
                color: client.state === "online" ? Colours.tPalette.m3primaryContainer : Colours.tPalette.m3surfaceContainerHighest

                StyledText {
                    id: statusText

                    anchors.centerIn: parent
                    text: client.state === "online" ? "online" : client.state === "connecting" ? "connecting…" : "offline"
                    color: client.state === "online" ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                }
            }

            // New session
            MaterialIcon {
                text: "add_comment"
                color: Colours.palette.m3onSurfaceVariant

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        transcript.clear();
                        root.busyState = false;
                        client.newSession();
                    }
                }
            }

            // Abort while the agent is working
            MaterialIcon {
                text: "stop_circle"
                visible: root.busy
                color: Colours.palette.m3error

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: client.abort()
                }
            }
        }

        // Model picker pill - own full-width row so a long model name can
        // never push the header past the panel width (Layouts treat their
        // implicit size as a minimum and would overflow the panel).
        StyledRect {
            id: modelPickerPill

            Layout.fillWidth: true
            radius: height / 2
            implicitHeight: modelNameText.implicitHeight + Tokens.padding.extraSmall * 0.75
            color: modelPicker.visible ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainer

            MaterialIcon {
                id: tuneIcon

                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.small
                anchors.verticalCenter: parent.verticalCenter
                text: "tune"
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                id: modelNameText

                anchors.left: tuneIcon.right
                anchors.leftMargin: Tokens.spacing.extraSmall
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.small
                anchors.verticalCenter: parent.verticalCenter
                text: client.modelName.length > 0 ? client.modelName : "model"
                color: Colours.palette.m3onSurfaceVariant
                elide: Text.ElideMiddle
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: modelPicker.open()
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

                delegate: ChatMessage {
                    agentClient: client
                }

                onCountChanged: Qt.callLater(list.positionViewAtEnd)
            }

            StyledText {
                anchors.centerIn: parent
                visible: transcript.count === 0
                text: client.state === "online" ? "Ask the chief anything.\nIt can run commands (with your approval),\nedit files and delegate to its crew." : client.state === "connecting" ? "Connecting to the agent daemon…" : "The agent daemon is offline.\nStart it with: systemctl --user start chiefd"
                horizontalAlignment: Text.AlignHCenter
                color: Colours.palette.m3outline
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

                    placeholderText: qsTr("Ask me anything…")
                    placeholderTextColor: Colours.palette.m3outline
                    color: Colours.palette.m3onSurface
                    wrapMode: TextArea.Wrap
                    background: null
                    enabled: client.state === "online"

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                            root.send();
                            event.accepted = true;
                        }
                    }
                }

                MaterialIcon {
                    text: "send"

                    color: input.length > 0 && client.state === "online" ? Colours.palette.m3primary : Colours.palette.m3outline

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.send()
                    }
                }
            }
        }
    }

    // Model picker popup
    Popup {
        id: modelPicker

        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 380
        height: Math.min(460, root.height - Tokens.padding.large * 2)
        padding: Tokens.padding.small
        modal: true

        background: StyledRect {
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer
        }

        contentItem: Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: Tokens.spacing.small

                StyledText {
                    text: "Choose a model"
                    font.bold: true
                }

                Flickable {
                    id: flick

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: providerColumn.implicitHeight

                    ScrollBar.vertical: ScrollBar {}

                    ColumnLayout {
                        id: providerColumn

                        width: flick.width
                        spacing: Tokens.spacing.extraSmall

                        Repeater {
                            model: client.providers

                            ColumnLayout {
                                id: providerSection

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 2

                                StyledText {
                                    text: providerSection.modelData.name ?? providerSection.modelData.providerID
                                    color: Colours.palette.m3primary
                                }

                                Repeater {
                                    model: providerSection.modelData.models ?? []

                                    Item {
                                        id: modelRow

                                        required property var modelData

                                        Layout.fillWidth: true
                                        implicitHeight: modelRowText.implicitHeight + Tokens.padding.small * 2

                                        readonly property bool selected: client.modelName === (providerSection.modelData.providerID + "/" + modelRow.modelData.modelID)

                                        StyledRect {
                                            anchors.fill: parent
                                            radius: Tokens.rounding.small
                                            color: modelRow.selected ? Colours.tPalette.m3secondaryContainer : "transparent"
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Tokens.padding.small
                                            anchors.rightMargin: Tokens.padding.small
                                            spacing: Tokens.spacing.small

                                            StyledText {
                                                id: modelRowText
                                                Layout.fillWidth: true
                                                text: modelRow.modelData.name ?? modelRow.modelData.modelID
                                                color: modelRow.selected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                            }

                                            StyledText {
                                                visible: modelRow.modelData.free
                                                text: "free"
                                                color: Colours.palette.m3primary
                                            }

                                            MaterialIcon {
                                                visible: modelRow.selected
                                                text: "check"
                                                color: Colours.palette.m3onSecondaryContainer
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                client.setModel(providerSection.modelData.providerID, modelRow.modelData.modelID);
                                                modelPicker.close();
                                            }
                                        }
                                    }
                                }
                            }
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
