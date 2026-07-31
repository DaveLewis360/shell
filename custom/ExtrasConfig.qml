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
//
// FONTOS — miért kötés és nem onLoaded:
// A `data` a file.text()-et HÍVJA egy kötésben, nem az onLoaded eventben veszi
// át. Ez a blockLoading működéséhez kell: a FileView csak akkor blokkol a
// betöltésig, ha tényleg meghívjuk a text()-et. Ha onLoaded-ből olvasnánk, a
// betöltés aszinkron maradna, és a shell egy pillanatra a HIBÁS alapértékkel
// épülne fel — a bar előbb vertikálisan, majd átugorva vízszintesre. Ilyenkor
// a Wayland exclusive zone mindkét élen bennemaradt (bal ÉS felső behúzás).
Singleton {
    id: root

    // ── Bar ──────────────────────────────────────────────────────────────
    // false = az eredeti, vertikális upstream bar
    // true  = a fork vízszintes barja (custom/bar/HBar.qml)
    readonly property bool horizontalBar: data.bar?.horizontal ?? false

    // ── MiniDash ─────────────────────────────────────────────────────────
    readonly property bool miniDash: data.miniDash?.enabled ?? true

    // Alapértékek, ha a fájl még nem létezik vagy hibás
    readonly property var defaults: ({
            bar: {
                horizontal: false
            },
            miniDash: {
                enabled: true
            }
        })

    // A nyers JSON. Kötés, nem esemény — lásd a fenti magyarázatot.
    readonly property var data: {
        const raw = file.text();
        if (!raw)
            return defaults;
        try {
            return JSON.parse(raw);
        } catch (e) {
            console.warn("[extras] hibás extras.json, alapértékek használva:", e);
            return defaults;
        }
    }

    function reload(): void {
        file.reload();
    }

    // Beállítás írása. A `data` kötés a text() változására magától újraértékel,
    // ezért itt nem kell (és nem is lehet) kézzel értéket adni neki.
    function setValue(section: string, key: string, value: var): void {
        const next = JSON.parse(JSON.stringify(root.data ?? {}));
        if (typeof next[section] !== "object" || next[section] === null)
            next[section] = {};
        next[section][key] = value;
        file.setText(JSON.stringify(next, null, 4) + "\n");
    }

    FileView {
        id: file

        path: `${Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config"}/caelestia/extras.json`
        printErrors: false
        watchChanges: true

        // A shell ablakai ELŐTT kell az érték, különben rossz orientációval épül
        // fel a bar. A dokumentáció pontosan erre az esetre ajánlja.
        blockLoading: true

        onFileChanged: reload()
        onLoadFailed: err => {
            // Nincs még fájl — letesszük a mintát, hogy legyen mit szerkeszteni
            if (err === FileViewError.FileNotFound)
                setText(JSON.stringify(root.defaults, null, 4) + "\n");
        }
    }
}
