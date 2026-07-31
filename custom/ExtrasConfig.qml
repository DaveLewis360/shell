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

    // ── Megjelenési stílus ───────────────────────────────────────────────
    // "floating" = önálló, kemény szélű lebegő panelek (a jelenlegi megjelenés,
    //              jellemzően átlátszó háttérrel)
    // "liquid"   = összeolvadó, rugalmas felületek: a panelek belépnek a
    //              BlobGroup SDF-mezőjébe, összeolvadnak egymással és a képernyő
    //              keretével, és mozgás közben rugósan deformálódnak
    //
    // Default a "floating", mert az a fork eddigi viselkedése — a stílus csak
    // akkor változik, ha kifejezetten átállítod.
    readonly property string appearanceStyle: data.appearance?.style ?? "floating"
    readonly property bool liquidStyle: appearanceStyle === "liquid"

    // ── Bar háttér: szigetes vagy folyamatos ─────────────────────────────
    // true  = szigetek: külön lekerekített blokkok, köztük átlátszó réssel
    // false = folyamatos: a bar a megvastagított képernyő-keret része, egyetlen
    //         felületet alkotva a panelekkel (upstream viselkedés)
    //
    // Ez korábban NEM volt külön beállítás: a vízszintes/vertikális váltó
    // döntötte el mellékhatásként. Ha a kulcs nincs a fájlban, a megjelenési
    // stílusból következik (liquid → folyamatos, floating → szigetek) — így egy
    // friss config magától értelmes, és amint hozzányúlsz, kifejezetté válik.
    // A stílus-váltó a beállításokban ezt a kulcsot presetként át is írja.
    //
    // Vertikális módban csak a folyamatos létezik: a sziget-geometria a vízszintes
    // bar elemeire épül (lásd HBar.rightPartX), ezért ott a kérés akkor is
    // folyamatosra oldódik fel, ha itt true szerepel.
    readonly property bool barIslands: data.bar?.islands ?? !liquidStyle

    // ── MiniDash ─────────────────────────────────────────────────────────
    // A pill rendes bar-elem (Config.bar.entries → "miniDash"); ez a mesterkapcsoló.
    readonly property bool miniDash: data.miniDash?.enabled ?? true

    // Alapértékek, ha a fájl még nem létezik vagy hibás
    readonly property var defaults: ({
            bar: {
                horizontal: false,
                islands: true
            },
            appearance: {
                style: "floating"
            },
            miniDash: {
                enabled: true
            }
        })

    // A nyers JSON értelmezése. Kötés, nem esemény — lásd a fenti magyarázatot.
    // Egy lépésben adja vissza az eredményt ÉS azt, hogy sikeres volt-e, hogy a
    // mentés meg tudja különböztetni a "még nincs fájl" és a "hibás fájl" esetet.
    readonly property var parseResult: {
        const raw = file.text();
        if (!raw)
            return ({
                    ok: true,
                    value: null
                });
        try {
            return ({
                    ok: true,
                    value: JSON.parse(raw)
                });
        } catch (e) {
            console.warn("[extras] hibás extras.json, alapértékek használva:", e);
            return ({
                    ok: false,
                    value: null
                });
        }
    }

    readonly property bool dataValid: parseResult.ok

    readonly property var data: parseResult.value ?? defaults

    function reload(): void {
        file.reload();
    }

    // Beállítás írása. A `data` kötés a text() változására magától újraértékel,
    // ezért itt nem kell (és nem is lehet) kézzel értéket adni neki.
    function setValue(section: string, key: string, value: var): void {
        // Hibás fájlnál a `data` az alapértékekre esett vissza, tehát a mentés az
        // EGÉSZ fájlt az alapértékekkel írná felül — elvinné a többi, kézzel
        // beírt kulcsot is, csak mert valahol lemaradt egy vessző. Ilyenkor előbb
        // félretesszük az eredetit, hogy visszanyerhető legyen.
        if (!dataValid) {
            console.warn("[extras] a fájl nem volt értelmezhető, mentés ide:", `${file.path}.broken`);
            Quickshell.execDetached(["cp", "--", file.path, `${file.path}.broken`]);
        }

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
