pragma ComponentBehavior: Bound

import QtQuick

// [fork] Placeholder transcript for the chat sidebar. The future agent daemon
// replaces this file's send() with real streamed responses; the UI reads only
// the `sender`/`text` roles, so the swap stays local to here.
ListModel {
    function send(text: string): void {
        const trimmed = text.trim();
        if (!trimmed)
            return;

        append({
            sender: "user",
            text: trimmed
        });

        append({
            sender: "assistant",
            text: "**A backend még nincs bekötve.**\n\nEz egy helykitöltő válasz — a chat felület a daemonra vár."
        });
    }

    Component.onCompleted: {
        append({
            sender: "assistant",
            text: "Szia! Én vagyok a fő agent.\n\nA backend még nincs bekötve, de a felület már él. Később itt tudok majd:\n\n- parancsokat futtatni (jóváhagyással)\n- ablakokat és workspacet vezérelni\n- alesgenseket delegálni\n\n```\n$ caelestia toggle chat\n```"
        });
    }
}
