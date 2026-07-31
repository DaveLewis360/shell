pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A homelab állapotát olvassa be a bar számára.
//
// Honnan jön az adat:
//   Egy gyűjtő script fut a homelabon (cron, percenként) és JSON fájlt ír, amit
//   a Caddy statikusan kiszolgál. Nincs hálózati szolgáltatás és nincs docker.sock
//   kitéve egy proxyzott konténerben — az effektíven root lenne.
//   Végpont: https://homelab.tailc34ac0.ts.net:8449/status.json
//
// Miért curl és nem XMLHttpRequest:
//   A végpont a Tailscale tanúsítványát használja, és csak tailnetről érhető el.
//   A Process/curl a shell többi részének idiómája (Quickshell.execDetached), és
//   a hibakezelés is átláthatóbb: a lekérés kilépési kódja megkülönbözteti a
//   "nem elérhető" (VPN le, gép alszik) és a "hibás válasz" esetet.
//
// Miért nem módosítja az ExtrasConfig.qml-t:
//   Az ExtrasConfig `data` property-je a NYERS beolvasott JSON, ezért a saját
//   szekciónk kiolvasható belőle anélkül, hogy a fájlhoz hozzányúlnánk. Így
//   nulla ütközés a fork saját, folyamatban lévő módosításaival.
//
// Beállítás (~/.config/caelestia/extras.json):
//   "homelab": {
//       "enabled": true,
//       "url": "https://homelab.tailc34ac0.ts.net:8449/status.json",
//       "intervalMs": 60000
//   }
Singleton {
    id: root

    // ── Beállítások, alapértékekkel ──────────────────────────────────────
    readonly property var cfg: ExtrasConfig.data?.homelab ?? ({})

    readonly property bool enabled: cfg.enabled ?? true
    readonly property string url: cfg.url ?? "https://homelab.tailc34ac0.ts.net:8449/status.json"
    readonly property int intervalMs: cfg.intervalMs ?? 60000

    // ── Kifelé adott állapot ─────────────────────────────────────────────
    // "ok" | "warn" | "crit" | "unknown"
    readonly property string state: reachable ? (payload.state ?? "unknown") : "unknown"

    // Egy soros összefoglaló — ez látszik a barban
    readonly property string summary: reachable ? (payload.short ?? "?") : "nem érhető el"

    readonly property bool reachable: lastExit === 0 && !!payload.state

    readonly property int critCount: payload.counts?.crit ?? 0
    readonly property int warnCount: payload.counts?.warn ?? 0

    // Memória
    readonly property int memAvailableMb: payload.memory?.available_mb ?? 0
    readonly property int memUsedPct: payload.memory?.used_pct ?? 0
    readonly property int swapUsedPct: payload.memory?.swap_used_pct ?? 0

    // Konténerek és mentés
    readonly property int containers: payload.containers ?? 0
    readonly property bool backupsRunning: payload.backups_running ?? false

    // Lemezek: a gyűjtő tömbben adja, a mount alapján keressük ki
    readonly property var disks: payload.disks ?? []
    readonly property real rootFreeGb: diskFree("/")
    readonly property real cardFreeGb: diskFree("/mnt/backup")
    readonly property bool cardMounted: diskMounted("/mnt/backup")

    // Mikor frissült utoljára — ha régi, azt jelezni kell, mert a bar
    // különben friss adatnak tűnő, órákkal ezelőtti számokat mutatna
    readonly property string generatedAt: payload.generated_at ?? ""
    property date lastFetch: new Date(0)
    readonly property int ageSeconds: Math.floor((now.getTime() - lastFetch.getTime()) / 1000)
    readonly property bool ageStale: ageSeconds > intervalMs / 1000 * 3

    // ── Belső ────────────────────────────────────────────────────────────
    property var payload: ({})
    property int lastExit: -1
    property date now: new Date()

    function diskFree(mount: string): real {
        for (const d of root.disks)
            if (d.mount === mount)
                return d.free_gb ?? 0;
        return 0;
    }

    function diskMounted(mount: string): bool {
        for (const d of root.disks)
            if (d.mount === mount)
                return d.mounted ?? false;
        return false;
    }

    function refresh(): void {
        if (!root.enabled)
            return;
        if (fetch.running)
            return;   // az előző lekérés még fut, ne halmozzuk
        fetch.running = true;
    }

    // A lekérés. --max-time: ha a gép alszik vagy a VPN le van, ne akadjon be.
    Process {
        id: fetch

        command: ["curl", "-sS", "--max-time", "8", "--fail", root.url]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.payload = JSON.parse(text);
                    root.lastFetch = new Date();
                } catch (e) {
                    // Hibás JSON: ne dobjuk el a régi értéket, csak jelezzük
                    console.warn("[homelab] értelmezhetetlen válasz:", e);
                    root.lastExit = -2;
                }
            }
        }

        onExited: code => {
            root.lastExit = code;
            if (code !== 0)
                root.payload = ({});   // nem elérhető: ne mutassunk régi adatot friss ként
        }
    }

    // Óra a "mennyire friss" számításhoz. Külön a lekéréstől, hogy az elavulás
    // akkor is látszódjon, ha a lekérés egyáltalán nem fut le.
    Timer {
        running: root.enabled
        interval: 5000
        repeat: true
        onTriggered: root.now = new Date()
    }

    Timer {
        running: root.enabled
        interval: root.intervalMs
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
