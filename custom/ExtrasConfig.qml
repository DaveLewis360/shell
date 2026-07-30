pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A fork saját beállításai.
//
// Miért külön fájl és nem a shell.json?
// Az upstream C++ ConfigObject CSAK a sémában definiált kulcsokat teszi ki QML
// property-ként. A 6e570081 commit óta az ismeretlen kulcsok MEGMARADNAK
// mentéskor (mergeUnknownKeys), de nem lesznek belőlük olvasható property-k.
// Ezért a saját beállítások külön fájlban élnek — így nulla ütközés az upstream
// mentési ciklusával, és upstream-módosítás sem kell hozzá.
//
// Fájl:  ~/.config/caelestia/extras.json
// Élő újratöltés: a FileView figyeli a fájlt, mentés után azonnal érvényes.
Singleton {
    id: root

    // ── Bar ──────────────────────────────────────────────────────────────
    // false = az eredeti, vertikális upstream bar
    // true  = a fork vízszintes barja (custom/bar/HBar.qml)
    readonly property bool horizontalBar: data.bar?.horizontal ?? false

    // ── MiniDash ─────────────────────────────────────────────────────────
    readonly property bool miniDash: data.miniDash?.enabled ?? true

    // A nyers JSON, ha valamit közvetlenül kell olvasni
    property var data: ({})

    // Alapértékek, ha a fájl még nem létezik
    readonly property var defaults: ({
        bar: {
            horizontal: false
        },
        miniDash: {
            enabled: true
        }
    })

    function reload(): void {
        file.reload();
    }

    FileView {
        id: file

        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/caelestia/extras.json`
        printErrors: false
        watchChanges: true

        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {
                console.warn("[extras] hibás extras.json, alapértékek használva:", e);
                root.data = root.defaults;
            }
        }
        onLoadFailed: err => {
            // Nincs még fájl — alapértékek, és letesszük a mintát
            root.data = root.defaults;
            if (err === FileViewError.FileNotFound)
                setText(JSON.stringify(root.defaults, null, 4) + "\n");
        }
    }
}
