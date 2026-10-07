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
            color: modelPicker.open ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainer

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
                onClicked: modelPicker.open = true
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

    // Model picker — opencode-style: search field on top, flat list with the
    // provider on the right of every row, keyboard navigation (up/down,
    // enter, escape). A plain in-panel overlay, NOT a QQuickPopup: a popup
    // escapes the drawers window's input region and its modal grab breaks
    // the HyprlandFocusGrab, which instantly closed the picker and the
    // panel itself.
    Item {
        id: modelPicker

        anchors.fill: parent

        property bool open: false
        // 500+ entries: build the catalog only when the picker is first opened
        property bool rowsLoaded: false
        property string search: ""
        property var flatModels: []
        property var filtered: []
        property int highlightIndex: 0

        onOpenChanged: {
            if (!open)
                return;
            rowsLoaded = true;
            rebuild();
            searchField.text = "";
            highlightSelected();
            searchField.forceActiveFocus();
        }

        function close(): void {
            open = false;
        }

        function highlightSelected(): void {
            highlightIndex = 0;
            for (let i = 0; i < filtered.length; i++) {
                const m = filtered[i];
                if (client.modelName === m.providerID + "/" + m.modelID) {
                    highlightIndex = i;
                    break;
                }
            }
            // the delegates for a freshly assigned model may not exist yet
            Qt.callLater(() => list.positionViewAtIndex(highlightIndex, ListView.Contain));
        }

        function rebuild(): void {
            const flat = [];
            const providers = client.providers ?? [];
            for (let p = 0; p < providers.length; p++) {
                const prov = providers[p];
                const pname = prov.name ?? prov.providerID;
                const models = prov.models ?? [];
                for (let i = 0; i < models.length; i++)
                    flat.push({
                        providerID: prov.providerID,
                        providerName: pname,
                        modelID: models[i].modelID,
                        name: models[i].name,
                        free: !!models[i].free
                    });
            }
            flatModels = flat;
            refilter();
        }

        function refilter(): void {
            const terms = search.trim().toLowerCase().split(/\s+/).filter(t => t.length > 0);
            const out = [];
            for (let i = 0; i < flatModels.length; i++) {
                const m = flatModels[i];
                if (terms.length > 0) {
                    const hay = (m.providerID + " " + m.providerName + " " + m.modelID + " " + (m.name ?? "")).toLowerCase();
                    let hit = true;
                    for (let t = 0; t < terms.length; t++) {
                        if (hay.indexOf(terms[t]) < 0) {
                            hit = false;
                            break;
                        }
                    }
                    if (!hit)
                        continue;
                }
                out.push(m);
            }
            filtered = out;
            if (highlightIndex >= out.length)
                highlightIndex = Math.max(0, out.length - 1);
        }

        function move(delta: int): void {
            if (filtered.length === 0)
                return;
            highlightIndex = Math.max(0, Math.min(filtered.length - 1, highlightIndex + delta));
            list.positionViewAtIndex(highlightIndex, ListView.Contain);
        }

        function select(index: int): void {
            const m = filtered[index];
            if (!m)
                return;
            client.setModel(m.providerID, m.modelID);
            close();
        }

        Connections {
            function onProvidersChanged(): void {
                if (modelPicker.rowsLoaded)
                    modelPicker.rebuild();
            }

            target: client
        }

        opacity: open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        // scrim + click-catcher
        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.large
            color: Colours.palette.m3scrim
            opacity: 0.35

            MouseArea {
                anchors.fill: parent
                onClicked: modelPicker.close()
            }
        }

        // The sheet: anchored under the model pill, right-aligned with the panel
        StyledRect {
            id: sheet

            anchors.top: modelPickerPill.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            height: Math.min(480, modelPicker.height - modelPickerPill.height - Tokens.padding.large * 2)
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.small

                StyledRect {
                    Layout.fillWidth: true
                    radius: height / 2
                    implicitHeight: searchField.implicitHeight + Tokens.padding.small * 2
                    color: Colours.tPalette.m3surfaceContainerHighest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "search"
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        TextArea {
                            id: searchField

                            Layout.fillWidth: true
                            placeholderText: qsTr("Search models…")
                            placeholderTextColor: Colours.palette.m3outline
                            color: Colours.palette.m3onSurface
                            background: null
                            wrapMode: TextArea.NoWrap

                            onTextChanged: {
                                modelPicker.search = text;
                                modelPicker.refilter();
                            }

                            Keys.onUpPressed: modelPicker.move(-1)
                            Keys.onDownPressed: modelPicker.move(1)
                            Keys.onReturnPressed: modelPicker.select(modelPicker.highlightIndex)
                            Keys.onEscapePressed: {
                                modelPicker.close();
                                input.forceActiveFocus();
                                event.accepted = true;
                            }
                        }
                    }
                }

                StyledListView {
                    id: list

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2

                    model: modelPicker.filtered

                    delegate: Item {
                        id: rowRoot

                        required property var modelData
                        required property int index

                        width: ListView.view?.width ?? 0
                        implicitHeight: rowName.implicitHeight + Tokens.padding.small * 2

                        readonly property bool isSelected: client.modelName === (modelData.providerID + "/" + modelData.modelID)
                        readonly property bool isHighlighted: index === modelPicker.highlightIndex

                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: rowRoot.isSelected ? Colours.tPalette.m3secondaryContainer : rowRoot.isHighlighted ? Colours.tPalette.m3surfaceContainerHighest : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            spacing: Tokens.spacing.small

                            StyledText {
                                id: rowName

                                Layout.fillWidth: true
                                text: rowRoot.modelData.name ?? rowRoot.modelData.modelID
                                elide: Text.ElideMiddle
                                color: rowRoot.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                            }

                            StyledText {
                                visible: rowRoot.modelData.free
                                text: "free"
                                color: Colours.palette.m3primary
                            }

                            StyledText {
                                text: rowRoot.modelData.providerName
                                color: Colours.palette.m3outline
                            }

                            MaterialIcon {
                                visible: rowRoot.isSelected
                                text: "check"
                                color: Colours.palette.m3onSecondaryContainer
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: modelPicker.highlightIndex = rowRoot.index
                            onClicked: modelPicker.select(rowRoot.index)
                        }
                    }
                }

                StyledText {
                    visible: list.count === 0
                    text: qsTr("No models match")
                    color: Colours.palette.m3outline
                }
            }
        }
    }

    // Grab keyboard focus whenever the panel opens, so the input can be typed into
    Connections {
        function onChatChanged(): void {
            if (root.screenState.chat) {
                modelPicker.close(); // never restore a stale picker across opens
                input.forceActiveFocus();
            }
        }

        target: root.screenState
    }
}
