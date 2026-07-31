pragma ComponentBehavior: Bound

import "../modules/bar/components"
import QtQuick
import Caelestia.Config
import qs.components
import qs.services

// A homelab legfontosabb mutatói a barban.
//
// Mit mutat, és miért pont ezt:
//   ikon + szín   az összesített állapot — egy pillantás, kell-e foglalkozni vele
//   szabad RAM    a homelabon 3,6 GB van és krónikusan swappol, ez a szűk keresztmetszet
//   lemez         a Nextcloud adat itt él; a Takeout előtt ez dönti el, mi fér be
//   konténerszám  ha kevesebb a szokásosnál, valami leállt
//   mentés-jelző  csak amíg fut — hogy tudd, miért lassú éppen a gép
//
// Az adatot a HomelabService adja (lásd ott, hogy honnan és miért úgy).
//
// Elavulás jelzése: ha a lekérés régi (pl. VPN le, vagy a gép alszik), a szám
// nem tűnhet frissnek. Ilyenkor a szín kioltott és az ikon átvált — különben
// órákkal ezelőtti értékeket olvasnál valósként.
StyledRect {
    id: root

    readonly property int padding: Tokens.padding.small

    readonly property bool stale: !HomelabService.reachable || HomelabService.ageStale

    readonly property color colour: {
        if (root.stale)
            return Colours.palette.m3outline;
        switch (HomelabService.state) {
        case "crit":
            return Colours.palette.m3error;
        case "warn":
            return Colours.palette.m3tertiary;
        case "ok":
            return Colours.palette.m3success;
        default:
            return Colours.palette.m3outline;
        }
    }

    readonly property string icon: {
        if (root.stale)
            return "cloud_off";
        switch (HomelabService.state) {
        case "crit":
            return "error";
        case "warn":
            return "warning";
        case "ok":
            return "cloud_done";
        default:
            return "cloud_off";
        }
    }

    implicitWidth: layout.implicitWidth + root.padding * 2
    implicitHeight: layout.implicitHeight + root.padding * 2

    color: "transparent"
    visible: HomelabService.enabled

    Row {
        id: layout

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter

            text: root.icon
            color: root.colour
        }

        // Nem elérhető: ne mutassunk semmilyen számot, mert az félrevezető lenne
        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: root.stale
            text: "homelab ?"
            font: Tokens.font.mono.small
            color: root.colour
        }

        // Szabad RAM — a homelab legszorosabb erőforrása
        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.stale
            text: `${HomelabService.memAvailableMb}M`
            font: Tokens.font.mono.small
            color: HomelabService.memAvailableMb < 300 ? Colours.palette.m3error : root.colour
        }

        // Gyökér-lemez szabad hely GB-ban
        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.stale
            text: `${Math.round(HomelabService.rootFreeGb)}G`
            font: Tokens.font.mono.small
            color: HomelabService.rootFreeGb < 40 ? Colours.palette.m3tertiary : root.colour
        }

        // Futó konténerek
        StyledText {
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.stale
            text: `${HomelabService.containers}c`
            font: Tokens.font.mono.small
            color: root.colour
        }

        // Csak amíg mentés fut — így látod, miért terhelt a gép
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.stale && HomelabService.backupsRunning
            text: "backup"
            color: Colours.palette.m3primary
        }

        // A microSD kivéve: a harmadik mentési példány nem készül
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter

            visible: !root.stale && !HomelabService.cardMounted
            text: "sd_card_alert"
            color: Colours.palette.m3tertiary
        }
    }

    // Kattintásra friss lekérés — ne kelljen a következő ciklusra várni
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: HomelabService.refresh()
    }
}
