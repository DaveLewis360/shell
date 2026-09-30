pragma ComponentBehavior: Bound

import QtQuick
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.modules.nexus.common

// Picks what the middle of the bar shows: nothing, the active window or the mini
// dashboard. It edits `bar.entries` like a hand-written config would: the chosen
// entry is enabled and the other one disabled. A missing entry is inserted where the
// other one is, or else after the first spacer, which upstream's default list puts
// before the centre.
SelectRow {
    id: root

    // Entry ids in menu order; "" is nothing
    readonly property list<string> ids: ["", "activeWindow", "miniDash"]
    readonly property list<MenuItem> items: [
        MenuItem {
            text: Tr.trCtx("Nothing", "bar centre")
            icon: "check_box_outline_blank"
        },
        MenuItem {
            text: Tr.tr("Active window")
            icon: "web_asset"
        },
        MenuItem {
            text: Tr.tr("Mini dashboard")
            icon: "monitoring"
        }
    ]

    readonly property string current: {
        const entries = Config.bar.entries.values;
        if (entries.some(e => e.enabled && e.id === "miniDash"))
            return "miniDash";
        if (entries.some(e => e.enabled && e.id === "activeWindow"))
            return "activeWindow";
        return "";
    }

    function choose(id: string): void {
        const entries = GlobalConfig.bar.entries;

        for (const other of ids) {
            if (!other)
                continue;

            let found = false;
            entries.values.forEach((e, i) => {
                if (e.id !== other)
                    return;
                found = true;
                if (e.enabled !== (other === id))
                    entries.at(i).enabled = other === id;
            });

            if (!found && other === id) {
                const values = entries.values;
                const sibling = values.findIndex(e => root.ids.includes(e.id) && e.id);
                const spacer = values.findIndex(e => e.id === "spacer");
                const at = sibling >= 0 ? sibling + 1 : spacer >= 0 ? spacer + 1 : -1;
                entries.insert({
                    id: other,
                    enabled: true
                }, at);
            }
        }
    }

    label: Tr.tr("Centre")
    subtext: current === "miniDash" && !GlobalConfig.fork.bar.horizontal ? Tr.tr("The mini dashboard only shows in the horizontal bar") : Tr.tr("What the middle of the bar shows")
    menuItems: items
    active: items[Math.max(0, ids.indexOf(current))]
    onSelected: item => choose(ids[items.indexOf(item)])
}
