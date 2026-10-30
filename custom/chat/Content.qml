pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
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
    property real busyStart: 0

    // Files staged in the composer for the next message. Items: {path, name}
    property var attachments: []

    onBusyStateChanged: {
        if (busyState) {
            busyStart = Date.now();
            busyElapsed.text = "0s";
        }
    }

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

        onPermissionHandled: (id, response) => {
            for (let i = transcript.count - 1; i >= 0; i--) {
                if (transcript.get(i).permId === id) {
                    transcript.setProperty(i, "answered", true);
                    transcript.setProperty(i, "answeredResponse", response);
                    break;
                }
            }
        }
    }

    ListModel {
        id: transcript
    }

    Timer {
        id: busyTimer

        interval: 1000
        repeat: true
        running: root.busyState

        onTriggered: root.updateBusyElapsed()
    }

    function updateBusyElapsed(): void {
        const s = Math.floor((Date.now() - root.busyStart) / 1000);
        busyElapsed.text = s < 60 ? s + "s" : Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    function pushEntry(props: var): void {
        transcript.append(Object.assign({
            sender: "",
            text: "",
            kind: "msg",
            permId: "",
            answered: false,
            answeredResponse: "",
            streaming: false,
            title: "",
            detail: ""
        }, props));
    }

    function send(): void {
        const text = input.text.trim();
        const files = attachments;
        if ((text.length === 0 && files.length === 0) || client.state !== "online")
            return;

        const names = files.map(f => f.name).join(", ");
        root.pushEntry({
            sender: "user",
            text: text + (names.length > 0 ? (text.length > 0 ? "\n\n" : "") + "`Attached: " + names + "`" : "")
        });
        client.send(text, files.map(f => ({
            path: f.path,
            name: f.name
        })));
        input.clear();
        attachments = [];
        root.busyState = true;
        list.positionViewAtEnd();
    }

    function attachPaths(paths: var): void {
        for (let i = 0; i < paths.length; i++) {
            const p = String(paths[i]).trim();
            if (p.length === 0)
                continue;
            const parts = p.split("/");
            root.addAttachment(p, parts[parts.length - 1]);
        }
    }

    function addAttachment(path: string, name: string): void {
        const list = attachments.slice();
        for (let i = 0; i < list.length; i++) {
            if (list[i].path === path)
                return; // the same file only once
        }
        list.push({
            path: path,
            name: name
        });
        attachments = list;
    }

    function removeAttachment(index: int): void {
        const list = attachments.slice();
        list.splice(index, 1);
        attachments = list;
    }

    function pasteClipboard(): void {
        // Image first (staged as an attachment), then text at the cursor -
        // wl-paste returns an empty string for formats the clipboard lacks.
        pasteImage.running = true;
        pasteText.running = true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        // Header: title, agent, status, session actions
        RowLayout {
            id: headerRow

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

            // Agent pill: the active agent, opens the picker
            StyledRect {
                id: agentPill

                radius: height / 2
                implicitWidth: agentPillRow.implicitWidth + Tokens.padding.small * 2
                implicitHeight: statusText.implicitHeight + Tokens.padding.extraSmall * 0.75
                color: agentPicker.open ? Colours.tPalette.m3surfaceContainerHighest : Colours.tPalette.m3surfaceContainer

                RowLayout {
                    id: agentPillRow

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        text: "smart_toy"
                        color: Colours.palette.m3onSurfaceVariant
                    }

                    StyledText {
                        text: client.agent.length > 0 ? client.agent : "agent"
                        color: Colours.palette.m3onSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        modelPicker.close();
                        agentPicker.open = true;
                    }
                }
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

        // Busy indicator (Claude Code-style): spinner + elapsed, interrupt at
        // hand. Lives between the transcript and the input so it is the first
        // thing seen while the model works.
        RowLayout {
            Layout.fillWidth: true
            visible: root.busyState
            spacing: Tokens.spacing.small

            MaterialIcon {
                text: "progress_activity"
                color: Colours.palette.m3primary

                RotationAnimation on rotation {
                    running: root.busyState
                    loops: Animation.Infinite
                    from: 0
                    to: 360
                    duration: 1200
                }
            }

            StyledText {
                text: qsTr("Working…")
                color: Colours.palette.m3onSurfaceVariant
            }

            StyledText {
                id: busyElapsed

                text: "0s"
                color: Colours.palette.m3outline
            }

            Item {
                Layout.fillWidth: true
            }

            // Interrupt
            MaterialIcon {
                text: "stop_circle"
                color: Colours.palette.m3error

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: client.abort()
                }
            }
        }

        // Input
        StyledRect {
            Layout.fillWidth: true

            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLow
            implicitHeight: inputColumn.implicitHeight + Tokens.padding.medium * 2

            ColumnLayout {
                id: inputColumn

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Tokens.padding.medium
                anchors.rightMargin: Tokens.padding.medium
                spacing: Tokens.spacing.small

                // Staged attachments: filename chips, click the cross to drop.
                Flow {
                    Layout.fillWidth: true
                    visible: root.attachments.length > 0
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: root.attachments

                        delegate: StyledRect {
                            id: chip

                            required property var modelData
                            required property int index

                            radius: height / 2
                            implicitWidth: chipRow.implicitWidth + Tokens.padding.small * 2
                            implicitHeight: chipRow.implicitHeight + Tokens.padding.extraSmall

                            color: Colours.tPalette.m3surfaceContainerHighest

                            RowLayout {
                                id: chipRow

                                anchors.centerIn: parent
                                spacing: Tokens.spacing.extraSmall

                                MaterialIcon {
                                    text: "attach_file"
                                    color: Colours.palette.m3onSurfaceVariant
                                }

                                StyledText {
                                    text: chip.modelData.name
                                    color: Colours.palette.m3onSurface
                                }

                                MaterialIcon {
                                    text: "close"
                                    color: Colours.palette.m3onSurfaceVariant

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.removeAttachment(chip.index)
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    id: inputRow

                    Layout.fillWidth: true
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
                            if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                                // own paste: text at the cursor + clipboard
                                // images staged as attachments
                                root.pasteClipboard();
                                event.accepted = true;
                                return;
                            }
                            if (event.key === Qt.Key_Return && !(event.modifiers & Qt.ShiftModifier)) {
                                root.send();
                                event.accepted = true;
                            }
                        }
                    }

                    // Attach files (native picker)
                    MaterialIcon {
                        text: "attach_file"
                        color: Colours.palette.m3onSurfaceVariant

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: fileDialog.running = true
                        }
                    }

                    MaterialIcon {
                        text: "send"

                        color: (input.length > 0 || root.attachments.length > 0) && client.state === "online" ? Colours.palette.m3primary : Colours.palette.m3outline

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.send()
                        }
                    }
                }
            }
        }

        // Native file picker: multiple selection, zenity joins the paths with
        // "|" (its default separator).
        Process {
            id: fileDialog

            command: ["zenity", "--file-selection", "--multiple", "--title=Attach files to the chat"]

            stdout: StdioCollector {
                onStreamFinished: {
                    const t = text.trim();
                    if (t.length > 0)
                        root.attachPaths(t.split("|"));
                }
            }
        }

        // Clipboard image -> attachment file (staged under /tmp).
        Process {
            id: pasteImage

            command: ["sh", "-c", "f=/tmp/chief-paste-$(date +%s%N).png; wl-paste -t image/png > \"$f\" 2>/dev/null; if [ -s \"$f\" ]; then printf '%s' \"$f\"; else rm -f \"$f\"; fi"]

            stdout: StdioCollector {
                onStreamFinished: {
                    const p = text.trim();
                    if (p.length > 0)
                        root.addAttachment(p, "pasted.png");
                }
            }
        }

        // Clipboard text -> inserted at the cursor (the TextArea's own ctrl-v
        // is intercepted above, so this is the only paste path).
        Process {
            id: pasteText

            command: ["sh", "-c", "wl-paste -t text"]

            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.length > 0) {
                        const pos = input.cursorPosition;
                        input.insert(pos, text);
                        input.cursorPosition = pos + text.length;
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

        // provider key management ("Manage keys")
        property bool authMode: false
        property string authProvider: ""   // non-empty: the key input targets this provider
        property int authHighlight: 0
        readonly property var authRows: {
            const seen = {};
            const out = [];
            const providers = client.providers ?? [];
            for (let i = 0; i < providers.length; i++) {
                const pid = providers[i].providerID;
                if (!seen[pid]) {
                    seen[pid] = true;
                    out.push({
                        providerID: pid,
                        name: providers[i].name ?? pid
                    });
                }
            }
            for (const pid in client.authProviders)
                if (!seen[pid])
                    out.push({
                        providerID: pid,
                        name: pid
                    });
            out.sort((a, b) => a.providerID.localeCompare(b.providerID));
            return out;
        }
        readonly property int connectedCount: Object.keys(client.authProviders).length

        onOpenChanged: {
            if (!open)
                return;
            rowsLoaded = true;
            authMode = false;
            authProvider = "";
            rebuild();
            searchField.text = "";
            highlightSelected();
            // both, because focus can be lost again during the open pass
            searchField.forceActiveFocus();
            Qt.callLater(() => searchField.forceActiveFocus());
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
            Qt.callLater(() => modelList.positionViewAtIndex(highlightIndex, ListView.Contain));
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
            modelList.positionViewAtIndex(highlightIndex, ListView.Contain);
        }

        function select(index: int): void {
            const m = filtered[index];
            if (!m)
                return;
            client.setModel(m.providerID, m.modelID);
            close();
        }

        function submitAuthKey(): void {
            const key = searchField.text.trim();
            if (authProvider.length === 0 || key.length === 0)
                return;
            client.setAuth(authProvider, key);
            searchField.text = "";
            authProvider = "";
            searchField.forceActiveFocus();
        }

        function moveAuth(delta: int): void {
            if (authRows.length === 0)
                return;
            authHighlight = Math.max(0, Math.min(authRows.length - 1, authHighlight + delta));
            authList.positionViewAtIndex(authHighlight, ListView.Contain);
        }

        function openAuthProvider(providerID: string): void {
            authMode = true;
            authProvider = providerID;
            searchField.text = "";
            searchField.forceActiveFocus();
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

        // The sheet: laid out under the model pill, right-aligned with the
        // panel. Raw palette (not tPalette): it floats over other windows'
        // content, translucency would make it unreadable. Positioned with a
        // y binding - the pill lives in the header layout, so anchors across
        // the two subtrees would be refused.
        StyledRect {
            id: sheet

            x: 0
            width: parent.width
            y: modelPickerPill.mapToItem(modelPicker, 0, 0).y + modelPickerPill.height + Tokens.spacing.small
            height: Math.min(500, modelPicker.height - y - Tokens.padding.large * 2)
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.small

                // search / API key input
                StyledRect {
                    id: searchBox

                    visible: modelPicker.authProvider.length === 0 || modelPicker.authMode
                    Layout.fillWidth: true
                    radius: height / 2
                    implicitHeight: searchField.implicitHeight + Tokens.padding.small * 2
                    color: Colours.palette.m3surfaceContainerHighest

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.small
                        anchors.rightMargin: Tokens.padding.small
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: modelPicker.authProvider.length > 0 ? "key" : "search"
                            color: Colours.palette.m3onSurfaceVariant
                        }

                        TextArea {
                            id: searchField

                            Layout.fillWidth: true
                            placeholderText: {
                                if (modelPicker.authProvider.length > 0)
                                    return qsTr("Paste the API key for %1…").arg(modelPicker.authProvider);
                                return modelPicker.authMode ? qsTr("Filter providers…") : qsTr("Search models…");
                            }
                            placeholderTextColor: Colours.palette.m3outline
                            color: Colours.palette.m3onSurface
                            background: null
                            wrapMode: TextArea.NoWrap

                            onTextChanged: {
                                if (modelPicker.authProvider.length > 0)
                                    return; // this is the key draft, not a filter
                                modelPicker.search = text;
                                modelPicker.refilter();
                            }

                            Keys.onUpPressed: {
                                if (modelPicker.authMode)
                                    modelPicker.moveAuth(-1);
                                else
                                    modelPicker.move(-1);
                            }
                            Keys.onDownPressed: {
                                if (modelPicker.authMode)
                                    modelPicker.moveAuth(1);
                                else
                                    modelPicker.move(1);
                            }
                            Keys.onReturnPressed: {
                                if (modelPicker.authProvider.length > 0)
                                    modelPicker.submitAuthKey();
                                else if (modelPicker.authMode)
                                    modelPicker.openAuthProvider(modelPicker.authHighlight);
                                else
                                    modelPicker.select(modelPicker.highlightIndex);
                            }
                            Keys.onEscapePressed: {
                                if (modelPicker.authProvider.length > 0) {
                                    modelPicker.authProvider = "";
                                    modelPicker.search = "";
                                } else if (modelPicker.authMode) {
                                    modelPicker.authMode = false;
                                    modelPicker.search = "";
                                } else {
                                    modelPicker.close();
                                    input.forceActiveFocus();
                                }
                                modelPicker.refilter();
                                event.accepted = true;
                            }
                        }
                    }
                }

                // hint while entering a key
                StyledText {
                    visible: modelPicker.authProvider.length > 0
                    Layout.fillWidth: true
                    text: qsTr("The key is stored by opencode for the '%1' provider (same as `opencode auth login`). Enter submits, Escape cancels.").arg(modelPicker.authProvider)
                    wrapMode: Text.Wrap
                    color: Colours.palette.m3onSurfaceVariant
                }

                // model list (search mode)
                StyledListView {
                    id: modelList

                    visible: !modelPicker.authMode
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
                            color: rowRoot.isSelected ? Colours.palette.m3secondaryContainer : rowRoot.isHighlighted ? Colours.palette.m3surfaceContainerHighest : "transparent"
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
                    visible: !modelPicker.authMode && modelList.count === 0
                    text: qsTr("No models match")
                    color: Colours.palette.m3outline
                }

                // provider access list (auth mode)
                StyledListView {
                    id: authList

                    visible: modelPicker.authMode && modelPicker.authProvider.length === 0
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2

                    model: modelPicker.authRows

                    delegate: Item {
                        id: authRow

                        required property var modelData
                        required property int index

                        width: ListView.view?.width ?? 0
                        implicitHeight: authName.implicitHeight + Tokens.padding.small * 2

                        readonly property bool connected: client.authProviders[modelData.providerID] === true
                        readonly property bool isHighlighted: index === modelPicker.authHighlight

                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: authRow.isHighlighted ? Colours.palette.m3surfaceContainerHighest : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: authRow.connected ? "key" : "key_off"
                                color: authRow.connected ? Colours.palette.m3primary : Colours.palette.m3outline
                            }

                            StyledText {
                                id: authName

                                Layout.fillWidth: true
                                text: authRow.modelData.name
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurface
                            }

                            StyledText {
                                visible: authRow.connected
                                text: qsTr("connected")
                                color: Colours.palette.m3outline
                            }

                            MaterialIcon {
                                visible: authRow.connected
                                text: "logout"
                                color: Colours.palette.m3outline

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: client.removeAuth(authRow.modelData.providerID)
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: modelPicker.authHighlight = authRow.index
                            onClicked: modelPicker.openAuthProvider(authRow.modelData.providerID)
                        }
                    }
                }

                StyledText {
                    visible: modelPicker.authMode && modelPicker.authProvider.length === 0 && authList.count === 0
                    text: qsTr("No providers available while the daemon is offline.")
                    color: Colours.palette.m3outline
                }

                // footer: status + mode switch
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "key"
                        color: Colours.palette.m3outline
                    }

                    StyledText {
                        text: modelPicker.authMode ? qsTr("Provider access") : qsTr("%1 of %2 providers connected").arg(modelPicker.connectedCount).arg(modelPicker.authRows.length)
                        color: Colours.palette.m3outline
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    StyledRect {
                        id: footerButton

                        radius: height / 2
                        implicitWidth: footerLabel.implicitWidth + Tokens.padding.small * 2
                        implicitHeight: footerLabel.implicitHeight + Tokens.padding.extraSmall * 2
                        color: Colours.palette.m3surfaceContainerHighest

                        StyledText {
                            id: footerLabel

                            anchors.centerIn: parent
                            text: {
                                if (modelPicker.authProvider.length > 0)
                                    return qsTr("Cancel");
                                return modelPicker.authMode ? qsTr("Back to models") : qsTr("Manage keys");
                            }
                            color: Colours.palette.m3primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelPicker.authProvider.length > 0) {
                                    modelPicker.authProvider = "";
                                    modelPicker.search = "";
                                } else {
                                    modelPicker.authMode = !modelPicker.authMode;
                                    modelPicker.search = "";
                                    modelPicker.authHighlight = 0;
                                }
                                modelPicker.refilter();
                                searchField.text = "";
                                searchField.forceActiveFocus();
                            }
                        }
                    }
                }
            }
        }
    }

    // Agent picker — same in-panel overlay pattern as the model picker: a
    // popup would escape the drawers window's input region and its modal
    // grab breaks the HyprlandFocusGrab, closing the whole panel. The list
    // is short (a handful of primary agents), so a plain sheet is enough -
    // keyboard navigation included, like the model picker.
    Item {
        id: agentPicker

        anchors.fill: parent

        property bool open: false
        property int highlightIndex: 0

        // The daemon reports the agents it knows (same .md pack); the local
        // fallback keeps the picker usable while the daemon is offline.
        readonly property var agents: client.agentsList.length > 0 ? client.agentsList : [{
            id: "chief",
            name: "Chief",
            icon: "auto_awesome",
            description: "Full crew - asks before running commands or editing files"
        }, {
            id: "planner",
            name: "Planner",
            icon: "psychology",
            description: "Plans and analyses - cannot run commands or edit files"
        }, {
            id: "unlocked",
            name: "Unlocked",
            icon: "lock_open",
            description: "Runs everything without asking - only for trusted work"
        }]

        onOpenChanged: {
            if (!open)
                return;
            // highlight the currently active agent
            highlightIndex = 0;
            for (let i = 0; i < agents.length; i++) {
                if (agents[i].id === client.agent) {
                    highlightIndex = i;
                    break;
                }
            }
            forceActiveFocus(); // keyboard navigation needs the focus
        }

        function close(): void {
            open = false;
            input.forceActiveFocus();
        }

        function move(delta: int): void {
            highlightIndex = Math.max(0, Math.min(agents.length - 1, highlightIndex + delta));
        }

        function choose(index: int): void {
            const a = agents[index];
            if (a)
                client.setAgent(a.id);
            close();
        }

        Keys.onUpPressed: agentPicker.move(-1)
        Keys.onDownPressed: agentPicker.move(1)
        Keys.onReturnPressed: agentPicker.choose(agentPicker.highlightIndex)
        Keys.onEnterPressed: agentPicker.choose(agentPicker.highlightIndex)
        Keys.onEscapePressed: agentPicker.close()

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
                onClicked: agentPicker.close()
            }
        }

        // Sheet laid out under the header (y binding: the header row lives
        // in another subtree, anchors across would be refused).
        StyledRect {
            id: agentSheet

            x: 0
            width: parent.width
            y: headerRow.mapToItem(agentPicker, 0, 0).y + headerRow.height + Tokens.spacing.small
            implicitHeight: agentColumn.implicitHeight + Tokens.padding.small * 2
            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainer

            ColumnLayout {
                id: agentColumn

                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.extraSmall

                Repeater {
                    model: agentPicker.agents

                    delegate: Item {
                        id: agentRow

                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        implicitHeight: agentRowText.implicitHeight + agentRowDesc.implicitHeight + Tokens.padding.small * 1.5

                        readonly property bool isSelected: client.agent === agentRow.modelData.id
                        readonly property bool isHighlighted: agentPicker.highlightIndex === agentRow.index

                        StyledRect {
                            anchors.fill: parent
                            radius: Tokens.rounding.small
                            color: agentRow.isSelected ? Colours.palette.m3secondaryContainer : agentRow.isHighlighted ? Colours.palette.m3surfaceContainerHighest : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.small
                            anchors.rightMargin: Tokens.padding.small
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                text: agentRow.modelData.icon ?? "smart_toy"
                                color: agentRow.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    id: agentRowText

                                    Layout.fillWidth: true
                                    text: agentRow.modelData.name
                                    color: agentRow.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    id: agentRowDesc

                                    Layout.fillWidth: true
                                    text: agentRow.modelData.description
                                    color: agentRow.isSelected ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3outline
                                    elide: Text.ElideRight
                                }
                            }

                            MaterialIcon {
                                visible: agentRow.isSelected
                                text: "check"
                                color: Colours.palette.m3onSecondaryContainer
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            hoverEnabled: true
                            onEntered: agentPicker.highlightIndex = agentRow.index
                            onClicked: agentPicker.choose(agentRow.index)
                        }
                    }
                }
            }
        }
    }

    // Grab keyboard focus whenever the panel opens, so the input can be typed into
    Connections {
        function onChatChanged(): void {
            if (root.screenState.chat) {
                modelPicker.close(); // never restore a stale picker across opens
                agentPicker.close();
                input.forceActiveFocus();
            }
        }

        target: root.screenState
    }
}
