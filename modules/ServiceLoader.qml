import QtQuick
import Quickshell
import Caelestia.Config
import qs.services
import qs.custom.media // [fork]

Scope {
    Component.onCompleted: {
        // Force certain singletons to load on shell init instead of lazily

        IdleInhibitor;
        GameMode;
        Notifs;
        Players;
        CoverArtCache; // [fork] copies art files before a browser deletes them
        Brightness;
        Weather.reload();

        if (GlobalConfig.utilities.vpn.enabled)
            VPN;
    }
}
