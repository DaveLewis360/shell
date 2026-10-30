pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// [fork] Bridge between the chat sidebar and chiefd (the agent daemon).
// Transport: a unix socket at $XDG_STATE_HOME/chief/agent.sock carrying
// newline-delimited JSON both ways. The daemon owns the opencode server.
QtObject {
    id: root

    readonly property string socketPath: {
        const stateHome = Quickshell.env("XDG_STATE_HOME");
        return (stateHome && stateHome.length > 0 ? stateHome : Quickshell.env("HOME") + "/.local/state") + "/chief/agent.sock";
    }

    // offline | connecting | online
    property string state: "connecting"
    property bool connected: false
    property string modelName: ""          // "provider/model" of the selected model
    property var providers: []             // [{providerID, name, models: [{modelID, name}]}]
    property var authProviders: ({})       // {providerID: true} - which providers have stored keys
    property string agent: ""              // active primary agent id (chief/planner/unlocked)
    property var agentsList: []            // [{id, name, icon, description}] offered by the daemon

    signal newMessage(string sender, string text)
    signal assistantText(string text)
    signal messageDone()
    signal permissionRequested(string id, string title, string detail)
    signal permissionHandled(string id, string response)

    // Fresh transport factory. A Socket whose first connect fails (daemon
    // down, stale socket file) never recovers on quickshell 0.3.1: the dead
    // QLocalSocket stays inside and later setConnected(true) calls are
    // ignored, so toggling `connected` cannot heal it. Recreating the
    // object always starts a real new attempt.
    property Component socketFactory: Component {
        Socket {
            parser: SplitParser {
                onRead: data => root.handleLine(data)
            }

            path: root.socketPath
            connected: true

            onConnectionStateChanged: {
                root.connected = connected;
            }
        }
    }

    property Socket socket

    function resetSocket(): void {
        if (socket) {
            socket.connected = false;
            socket.destroy();
        }
        socket = socketFactory.createObject(root);
    }

    Component.onCompleted: resetSocket()

    // Recreate the transport until the daemon greets us with a status frame.
    // Only a dead transport is replaced; a live one that is still waiting
    // for its greeting is left alone. This also covers the stuck case where
    // the daemon replaced the socket file underneath us: the old connection
    // drops, connectionStateChanged flips us back to offline/connecting,
    // and the next tick rebuilds the transport.
    property Timer reconnect: Timer {
        interval: 2500
        running: !root.connected || root.state !== "online"
        repeat: true

        onTriggered: {
            if (root.socket && !root.socket.connected)
                root.resetSocket();
        }
    }

    onConnectedChanged: {
        if (connected) {
            state = "connecting"; // online once the daemon greets us with a status frame
        } else {
            state = "offline";
            modelName = "";
        }
    }

    function handleLine(line: string): void {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            return;
        }

        switch (msg.type) {
        case "status":
            state = msg.state ?? "online";
            // the daemon stores the model in opencode's API form {providerID, id}
            modelName = msg.model ? (msg.model.providerID + "/" + (msg.model.modelID ?? msg.model.id)) : "";
            if (msg.agent)
                agent = msg.agent;
            break;
        case "agents":
            agentsList = msg.agents ?? [];
            break;
        case "models":
            providers = msg.providers ?? [];
            break;
        case "auth":
            authProviders = msg.providers ?? {};
            break;
        case "history":
            for (let i = 0; i < (msg.messages ?? []).length; i++)
                newMessage(msg.messages[i].sender, msg.messages[i].text);
            state = "online";
            break;
        case "assistantText":
            assistantText(msg.text ?? "");
            break;
        case "messageDone":
            messageDone();
            break;
        case "permission":
            permissionRequested(msg.id ?? "", msg.title ?? "", msg.detail ?? "");
            break;
        case "error":
            newMessage("assistant", "**Error:** " + (msg.message ?? "unknown"));
            messageDone();
            break;
        }
    }

    function send(text: string, files: var): void {
        write({
            type: "send",
            text: text,
            files: files ?? []
        });
    }

    function respondPermission(id: string, response: string): void {
        // Let the transcript mark the card answered BEFORE the round-trip so
        // the UI never shows stale buttons on a slow link.
        permissionHandled(id, response);
        write({
            type: "permission",
            id: id,
            response: response
        });
    }

    function abort(): void {
        write({
            type: "abort"
        });
    }

    function newSession(): void {
        write({
            type: "newSession"
        });
    }

    function setModel(providerID: string, modelID: string): void {
        write({
            type: "setModel",
            providerID: providerID,
            modelID: modelID
        });
    }

    function setAgent(agent: string): void {
        write({
            type: "setAgent",
            agent: agent
        });
    }

    function setAuth(provider: string, key: string): void {
        write({
            type: "setAuth",
            provider: provider,
            key: key
        });
    }

    function removeAuth(provider: string): void {
        write({
            type: "removeAuth",
            provider: provider
        });
    }

    function write(obj: var): void {
        if (!connected)
            return;
        socket.write(JSON.stringify(obj) + "\n");
        socket.flush();
    }
}
