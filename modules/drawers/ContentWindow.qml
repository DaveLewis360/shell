pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia.Blobs
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.custom
import qs.services
import qs.modules.bar

StyledWindow {
    id: root

    readonly property alias bar: bar
    readonly property alias interactionWrapper: interactions

    readonly property ScreenState screenState: ShellState.forScreen(screen)

    readonly property HyprlandMonitor monitor: Hypr.monitorFor(screen)
    readonly property bool hasSpecialWorkspace: (monitor?.lastIpcObject.specialWorkspace?.name.length ?? 0) > 0
    readonly property bool hasFullscreenOnNormalWs: monitor?.activeWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false
    readonly property bool hasFullscreen: {
        if (hasSpecialWorkspace) {
            const specialName = monitor?.lastIpcObject.specialWorkspace?.name;
            if (!specialName)
                return false;
            const specialWs = Hypr.workspaces.values.find(ws => ws.name === specialName);
            return specialWs?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false;
        }
        return hasFullscreenOnNormalWs;
    }

    property real fsTransitionProg: hasFullscreen ? 1 : 0
    readonly property real sdfBorderOffset: 2 * fsTransitionProg // SDFs joins are not exact, so offset by 2px to ensure nothing shows
    readonly property real borderThickness: contentItem.Config.border.thickness * (1 - fsTransitionProg)
    readonly property real borderRounding: contentItem.Config.border.rounding * (1 - fsTransitionProg)
    readonly property real shadowOpacity: 0.7 * (1 - fsTransitionProg)
    readonly property real borderLayoutThickness: hasFullscreen ? 0 : contentItem.Config.border.thickness

    property color surfaceColour: Colours.tPalette.m3surface

    // [fork] Megjelenési stílus. Liquid módban a panelek háttere BlobRect, ami
    // belép a blobGroup SDF-mezőjébe: összeolvad a képernyő keretével és a
    // szomszédos panelekkel, és mozgás közben rugósan deformálódik. Floating
    // módban egyszerű Rectangle — kemény szélű, önálló panel. Lásd a PanelBg
    // komponenst a fájl alján.
    readonly property bool liquidStyle: ExtrasConfig.liquidStyle

    // [fork] Szigetes bar-háttér. Korábban ezt a vízszintes/vertikális váltó
    // döntötte el mellékhatásként, majd egy ideig csak vízszintesen működött; most
    // mindkét orientációban él. A geometriát a bar szolgáltatja a saját tengelye
    // mentén (BarWrapper.clusterStart és .islandEntries), ezért itt csak azt kell
    // eldönteni, melyik tengelyre képezzük le.
    readonly property bool barIslands: ExtrasConfig.barIslands

    readonly property int dragMaskPadding: {
        if (focusGrab.active || panels.popouts.isDetached)
            return 0;

        if (monitor?.lastIpcObject.specialWorkspace?.name || monitor?.activeWorkspace?.lastIpcObject.windows > 0)
            return 0;

        const thresholds = [];
        for (const panel of ["dashboard", "launcher", "session", "sidebar"])
            if (contentItem.Config[panel].enabled)
                thresholds.push(contentItem.Config[panel].dragThreshold);
        return Math.max(...thresholds);
    }

    onHasFullscreenChanged: {
        screenState.launcher = false;
        screenState.session = false;
        screenState.dashboard = false;
        panels.popouts.close();
    }

    name: "drawers"
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: (fsTransitionProg > 0 && contentItem.Config.general.showOverFullscreen) || (hasSpecialWorkspace && hasFullscreenOnNormalWs) ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: screenState.launcher || screenState.session ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: hasFullscreen ? emptyRegion : regions

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    Behavior on fsTransitionProg {
        Anim {}
    }

    Behavior on surfaceColour {
        CAnim {}
    }

    Region {
        id: emptyRegion

        x: panels.notifications.x + (bar.horizontal ? root.borderThickness : bar.implicitWidth)
        y: panels.notifications.y + (bar.horizontal ? bar.implicitHeight : root.borderThickness)
        width: panels.notifications.width
        height: panels.notifications.height

        Region {
            x: bar.horizontal ? panels.osdWrapper.x + root.borderThickness : root.width - width
            y: bar.horizontal ? root.height - height : panels.osdWrapper.y + root.borderThickness
            width: bar.horizontal ? panels.osd.width : panels.osdWrapper.width * (1 - panels.osd.offsetScale) + root.borderThickness
            height: bar.horizontal ? panels.osdWrapper.height * (1 - panels.osd.offsetScale) + root.borderThickness : panels.osd.height
        }
    }

    Regions {
        id: regions

        bar: bar
        panels: panels
        win: root
    }

    HyprlandFocusGrab {
        id: focusGrab

        active: {
            const s = root.screenState;
            const conf = root.contentItem.Config;
            if ((s.launcher && conf.launcher.enabled) || (s.session && conf.session.enabled) || (s.sidebar && conf.sidebar.enabled))
                return true;
            if (!conf.dashboard.showOnHover && s.dashboard && conf.dashboard.enabled)
                return true;
            if (panels.popouts.currentName.startsWith("traymenu") && (panels.popouts.current as StackView)?.depth > 1)
                return true;
            return false;
        }
        windows: [root]
        onCleared: {
            root.screenState.launcher = false;
            root.screenState.session = false;
            root.screenState.sidebar = false;
            root.screenState.dashboard = false;
            panels.popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    StyledRect {
        anchors.fill: parent
        opacity: (root.screenState.session && Config.session.enabled) || panels.popouts.detachedMode !== "" ? 0.5 : 0
        color: Colours.palette.m3scrim

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: root.surfaceColour.a
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            blurMax: 15
            shadowColor: Qt.alpha(Colours.palette.m3shadow, Math.max(0, root.shadowOpacity))
        }

        BlobGroup {
            id: blobGroup

            color: root.surfaceColour
            smoothing: root.contentItem.Config.border.smoothing
        }

        BlobInvertedRect {
            id: screenBorderBlob

            anchors.fill: parent
            anchors.margins: -50 // Make border thicker to smooth out bulge from closed drawers
            group: blobGroup
            radius: root.borderRounding

            // [fork] Folyamatos módban a bar a képernyő-keret helyi
            // megvastagítása: vertikálisan a bal, vízszintesen a felső él nyúlik
            // be a bar teljes vastagságáig, így a bar és a panelek egyetlen
            // felületet alkotnak. Szigetes módban a keret mindkét élen vékony
            // marad, és a bar hátterét a sziget-blokkok adják.
            borderLeft: (bar.horizontal || root.barIslands ? root.borderThickness : bar.implicitWidth) - anchors.margins - root.sdfBorderOffset
            borderRight: root.borderThickness - anchors.margins - root.sdfBorderOffset
            borderTop: (!bar.horizontal || root.barIslands ? root.borderThickness : bar.implicitHeight) - anchors.margins - root.sdfBorderOffset
            borderBottom: root.borderThickness - anchors.margins - root.sdfBorderOffset
        }

        PanelBg {
            id: dashBg

            panel: panels.dashboard
            deformAmount: 0.1
        }

        PanelBg {
            id: launcherBg

            panel: panels.launcher
            deformAmount: 0.1
        }

        PanelBg {
            id: sessionBg

            panel: panels.sessionWrapper
            deformAmount: 0.2
        }

        PanelBg {
            id: sidebarBg

            panel: panels.sidebar
            extraHeight: 2
            deformAmount: 0.03

            // [fork] Liquid módban a sidebar és az utilities csak akkor olvadhat
            // össze, ha a sidebar már láthatóan kinyílt; csukott állapotban külön
            // kell maradniuk, különben a kettő egy formátlan tömbbé folyik. A
            // sarok pedig a kinyílással együtt kerekedik le. Mindkettő upstream
            // viselkedés, amit a BlobRect elhagyásával elveszett — floating
            // módban egyszerűen nincs hatása.
            excludeBgs: panels.sidebar.offsetScale > 0.08 ? [] : [utilsBg]
            cornerBottomLeft: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * sidebarBg.cornerRadius
        }

        PanelBg {
            id: osdBg

            panel: panels.osdWrapper
            deformAmount: 0.25
        }

        PanelBg {
            id: notifsBg

            panel: panels.notifications
        }

        PanelBg {
            id: utilsBg

            panel: panels.utilities
            deformAmount: panels.sidebar.visible ? 0.1 : 0.15
            excludeBgs: panels.sidebar.offsetScale > 0.08 ? [] : [sidebarBg]
            cornerTopLeft: Math.max(0, Math.min(1, panels.sidebar.offsetScale / 0.3)) * utilsBg.cornerRadius
        }

        PanelBg {
            id: popoutBg

            panel: panels.popoutsWrapper
        }

        // [fork] A szigetes bar-háttér. Csak szigetes módban látszik; folyamatos
        // módban a képernyő-keret nyúlik be a bar alá helyette.
        //
        // Két rész van: a bar végén lévő összefüggő blokk (barBg), és a magukban
        // álló elemek (workspaces, illetve a középső slot). Ez utóbbi azért kell,
        // mert a pillek áttetsző m3surfaceContainer-t festenek — tömör backdrop
        // nélkül közvetlenül a wallpaperre kerültek, és alig látszottak.
        //
        // A bar a geometriát a SAJÁT tengelye mentén adja (pos/len), a rá merőleges
        // méret a `thick`; itt csak leképezzük a megfelelő tengelyre.
        Repeater {
            model: root.barIslands ? bar.islandEntries : []

            Rectangle {
                required property var modelData

                x: bar.horizontal ? modelData.pos : bar.x + (bar.implicitWidth - modelData.thick) / 2
                y: bar.horizontal ? bar.y + (bar.implicitHeight - modelData.thick) / 2 : modelData.pos
                implicitWidth: bar.horizontal ? modelData.len : modelData.thick
                implicitHeight: bar.horizontal ? modelData.thick : modelData.len
                radius: modelData.r
                color: Qt.alpha(root.surfaceColour, 1)
            }
        }

        Rectangle {
            id: barBg

            visible: root.barIslands
            x: bar.horizontal ? bar.clusterStart : bar.x
            y: bar.horizontal ? bar.y : bar.clusterStart
            implicitWidth: bar.horizontal ? bar.width - bar.clusterStart : bar.implicitWidth
            implicitHeight: bar.horizontal ? bar.implicitHeight : bar.height - bar.clusterStart
            radius: root.borderRounding
            color: Qt.alpha(root.surfaceColour, 1)
        }
    }

    Interactions {
        id: interactions

        screen: root.screen
        popouts: panels.popouts
        screenState: root.screenState
        panels: panels
        bar: bar
        borderThickness: root.borderLayoutThickness
        fullscreen: root.hasFullscreen

        Panels {
            id: panels

            screen: root.screen
            screenState: root.screenState
            bar: bar
            borderThickness: root.borderThickness

            utilities.horizontalStretch: 1
        }

        BarWrapper {
            id: bar

            // [fork] vízszintes: felső él, teljes szélesség
            //        vertikális: bal él, teljes magasság (upstream)
            // Feltételes anchor helyett explicit méret — az `undefined` anchor
            // nem törli a kötést, attól feszült volna mindkét élre.
            anchors.top: parent.top
            anchors.left: parent.left
            width: bar.horizontal ? parent.width : bar.implicitWidth
            height: bar.horizontal ? bar.implicitHeight : parent.height

            screen: root.screen
            screenState: root.screenState
            popouts: panels.popouts

            fullscreen: root.hasFullscreen
        }
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "rootWindow"
        component: root
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "interactionWrapper"
        component: interactions
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "bar"
        component: bar
    }

    ShellState.ComponentRef {
        screen: root.screen
        slot: "panels"
        component: panels
    }

    // [fork] A panelek háttere. A megjelenési stílus dönti el, MI rajzolja:
    //
    //   liquid   → BlobRect, ami belép a blobGroup SDF-mezőjébe. A panelek
    //              összeolvadnak egymással és a képernyő keretével (a
    //              border.smoothing szerint), és mozgás közben rugósan
    //              deformálódnak. Ez az upstream viselkedés.
    //   floating → egyszerű Rectangle: kemény szélű, önálló panel. Ez a fork
    //              eddigi és továbbra is alapértelmezett megjelenése.
    //
    // Miért Loader és nem egyetlen típus: a BlobRect a színt a csoporttól kapja
    // (a BlobShape-nek nincs is color property-je), a Rectangle viszont maga
    // festi magát — a kettő nem hozható egy típus alá. A wrapper Item mindkét
    // esetben ugyanazt a geometriát és láthatóságot adja, így a nyolc hívási hely
    // nem tud a különbségről.
    //
    // A `visible`/`opacity` a wrapperen van: egy nulla hozzájárulású blob eleve
    // láthatatlan, egy Rectangle viszont kirajzolná magát, ezért ezt nem lehet a
    // belső elemre bízni.
    component PanelBg: Item {
        id: bg

        required property Item panel
        property real deformAmount: 0.15
        property real cornerRadius: Tokens.rounding.extraLarge
        property real extraHeight: 0

        // Liquid módban ezekkel a panelekkel NEM olvadhat össze. Wrappereket vár,
        // és a BlobRect-jeiket szedi ki belőlük — az exclude lista BlobRect
        // példányokat kíván, nem wrappereket.
        property var excludeBgs: []

        // Sarok-rádiusz felülírás liquid módban; -1 = a cornerRadius érvényes
        // (ez a BlobRect saját neutrális értéke).
        property real cornerTopLeft: -1
        property real cornerBottomLeft: -1

        readonly property BlobRect blob: bgLoader.item as BlobRect

        x: panel.x + (bar.horizontal ? root.borderThickness : bar.implicitWidth)
        y: panel.y + (bar.horizontal ? bar.implicitHeight : root.borderThickness)
        implicitWidth: panel.width
        implicitHeight: panel.height + extraHeight
        visible: panel.visible
        opacity: panel.opacity !== undefined ? panel.opacity : 1

        Loader {
            id: bgLoader

            anchors.fill: parent
            sourceComponent: root.liquidStyle ? liquidBg : flatBg
        }

        Component {
            id: liquidBg

            BlobRect {
                group: blobGroup
                radius: bg.cornerRadius
                topLeftRadius: bg.cornerTopLeft
                bottomLeftRadius: bg.cornerBottomLeft
                deformScale: (bg.deformAmount * bg.Config.appearance.deformScale) / 10000
                exclude: bg.excludeBgs.map(w => w.blob).filter(b => !!b)
            }
        }

        Component {
            id: flatBg

            Rectangle {
                radius: bg.cornerRadius
                color: Qt.alpha(root.surfaceColour, 1)
            }
        }
    }
}
