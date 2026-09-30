pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.controls
import qs.components.widgets
import qs.services
import qs.utils

// The top bar's centre as a small dashboard: the `miniDash` bar entry.
//
// It speaks the bar's own language. The player sits exactly in the middle, in a
// capsule with the surface and rounding of the workspaces one, a step taller as
// the bar's main piece. It holds the cover, the track, the dashboard's wavy seek
// slider and a button group whose play button morphs from a pill to a rounded
// rectangle while playing. Its width is fixed, the slider taking what the title
// leaves, so nothing around it moves between tracks. The load flanks it as bare
// readouts in the clock's type and colour: the processor (use, temperature) on the
// left, memory and disk on the right, both sides equally wide so the player stays
// centred. When the bar cannot fit them (a small screen, an opened tray), the load
// fades out and the player keeps its size.
//
// It is the dashboard folded into the bar: the player opens the dashboard's media
// tab, the load its performance tab. The GPU is left to that tab: reading it runs
// nvidia-smi every second, which would keep a hybrid laptop's discrete GPU awake
// all the time. Without a player the capsule folds into a round button. Only the
// top bar has the entry; the vertical bar skips ids it does not know.
Item {
    id: root

    required property ScreenState screenState
    // The HBar, for the room the centre has; null outside a bar
    required property var bar

    readonly property bool hasMedia: !!Players.active && Players.active.trackTitle.length > 0
    readonly property bool isPlaying: Players.active?.isPlaying ?? false
    readonly property real length: Players.active?.length ?? 0
    readonly property bool canSeek: length > 0 && length <= 2147483647 && (Players.active?.canSeek ?? false) && (Players.active?.positionSupported ?? false)

    // Sizes, all from the bar's own
    readonly property real size: Tokens.sizes.bar.innerWidth
    readonly property real ringSize: size - Tokens.padding.medium
    readonly property real ringStroke: Math.round(Tokens.padding.extraSmall * 0.75)
    readonly property real mediaSize: size + Tokens.padding.small // The player capsule's height
    readonly property real mediaWidth: size * 13.5
    readonly property real coverSize: size
    readonly property real mediaButtonSize: mediaSize - Tokens.padding.large
    readonly property real seekThickness: Tokens.padding.small
    readonly property real gap: Tokens.spacing.large // Between loads
    readonly property color loadColour: Colours.palette.m3tertiary // The clock's
    readonly property real groupGap: Tokens.spacing.extraLarge // Between the loads and the player
    readonly property real titleWidth: size * 4.5
    readonly property real flankWidth: Math.max(leftLoads.implicitWidth, rightLoads.implicitWidth)
    readonly property real room: bar?.centreRoomFor(this) ?? Infinity
    readonly property bool showLoad: room >= (flankWidth + groupGap) * 2 + capsule.implicitWidth

    // The clock's type: its time for values and titles, its weekday for details
    readonly property font primaryFont: Tokens.font.body.builders.small.scale(1.1).build()
    readonly property font titleFont: Tokens.font.title.small
    readonly property font secondaryFont: Tokens.font.body.builders.small.scale(0.9).build()
    readonly property real hotTemperature: 90 // °C, where the dashboard's performance tab warns
    readonly property bool hot: Cpu.temperature > hotTemperature

    function openDashboard(tab: string): void {
        const tabs = [["dashboard", Config.dashboard.showDashboard], ["media", Config.dashboard.showMedia], ["performance", Config.dashboard.showPerformance], ["weather", Config.dashboard.showWeather]];
        const index = tabs.filter(t => t[1]).findIndex(t => t[0] === tab);
        if (index >= 0)
            screenState.dashboardTab = index;
        screenState.dashboard = true;
    }

    implicitWidth: (showLoad ? (flankWidth + groupGap) * 2 : 0) + capsule.implicitWidth
    implicitHeight: Math.max(size, capsule.implicitHeight)

    // The open dashboard covers the entry; its tabs must get the clicks
    enabled: !screenState.dashboard

    // The player reports its position only when asked, as on the dashboard
    Timer {
        running: root.isPlaying && root.enabled
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: Players.active?.positionChanged()
    }

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    // Processors, towards the middle
    Flank {
        anchors.right: capsule.left
        anchors.rightMargin: root.groupGap
        loads: leftLoads

        RowLayout {
            id: leftLoads

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.gap

            Load {
                icon: "memory"
                value: Cpu.percentage
                text: Strings.percentOne(Cpu.percentage)
                widest: Strings.percentOne(1)
            }

            // Filled to the temperature out of 100 °C, as the dashboard's bar is
            Load {
                icon: root.hot ? "thermometer_alert" : "thermometer"
                value: Cpu.temperature / 100
                text: Units.formatSensorTemp(Cpu.temperature)
                widest: Units.formatSensorTemp(100)
                hot: root.hot
            }
        }
    }

    // The player, in the middle
    StyledRect {
        id: capsule

        anchors.centerIn: parent
        implicitWidth: root.hasMedia ? root.mediaWidth : root.size
        implicitHeight: root.hasMedia ? root.mediaSize : root.size

        clip: true
        color: Colours.tPalette.m3surfaceContainer
        radius: Tokens.rounding.full

        Behavior on implicitWidth {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        Behavior on implicitHeight {
            Anim {
                type: Anim.DefaultSpatial
            }
        }

        StateLayer {
            radius: capsule.radius
            onClicked: root.openDashboard("media")
        }

        MaterialIcon {
            anchors.centerIn: parent
            text: "music_note"
            color: Colours.palette.m3onSurfaceVariant
            opacity: root.hasMedia ? 0 : 1

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }
        }

        // Laid out at full size, so a folding or unfolding capsule clips it instead
        // of squeezing it
        RowLayout {
            id: player

            anchors.left: parent.left
            anchors.leftMargin: (root.mediaSize - root.coverSize) / 2
            anchors.verticalCenter: parent.verticalCenter
            width: root.mediaWidth - anchors.leftMargin - (root.mediaSize - root.mediaButtonSize) / 2
            spacing: 0

            opacity: root.hasMedia ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Anim {
                    type: Anim.DefaultEffects
                }
            }

            CoverArt {
                implicitWidth: root.coverSize
                implicitHeight: root.coverSize
            }

            ColumnLayout {
                Layout.leftMargin: Tokens.spacing.medium
                Layout.maximumWidth: root.titleWidth
                spacing: -Tokens.spacing.extraSmall

                StyledText {
                    Layout.fillWidth: true
                    animate: true
                    text: Players.active?.trackTitle ?? ""
                    color: Colours.palette.m3primary
                    font: root.titleFont
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    animate: true
                    text: Players.active?.trackArtist || Players.active?.identity || ""
                    color: Colours.palette.m3onSurfaceVariant
                    font: root.secondaryFont
                    elide: Text.ElideRight
                }
            }

            // The dashboard's seek slider: wavy, the wave moving while playing
            StyledSlider {
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.spacing.large
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: root.seekThickness

                value: root.length > 0 ? (Players.active?.position ?? 0) / root.length : 0
                enabled: root.canSeek
                wavy: true
                animateWave: root.isPlaying
                // A wave every 40 px or so, however long the slider gets
                waveFrequency: Math.max(2, Math.round(width / 40))
                waveDuration: 2000
                interactionOnMove: false
                onInteraction: value => {
                    if (root.canSeek)
                        Players.active.position = value * root.length;
                }
            }

            RowLayout {
                Layout.leftMargin: Tokens.spacing.medium
                spacing: Tokens.spacing.extraSmall

                MediaButton {
                    icon: "skip_previous"
                    disabled: !Players.active?.canGoPrevious
                    onClicked: Players.active?.previous()
                }

                // The main action: filled and wider, a pill while paused and a
                // rounded rectangle while playing, like the dashboard's
                MediaButton {
                    implicitWidth: Math.round(implicitHeight * 1.3)
                    implicitHeight: root.coverSize
                    type: IconButton.Filled
                    font: Tokens.font.icon.medium
                    checkedRadius: Tokens.rounding.medium
                    pressedRadius: Tokens.rounding.small
                    icon: root.isPlaying ? "pause" : "play_arrow"
                    // Bound, not `checked`: that only morphs on a change, not when
                    // the entry is created mid-song
                    internalChecked: root.isPlaying
                    disabled: !Players.active?.canTogglePlaying
                    onClicked: Players.active?.togglePlaying()
                }

                MediaButton {
                    icon: "skip_next"
                    disabled: !Players.active?.canGoNext
                    onClicked: Players.active?.next()
                }
            }
        }
    }

    // Memory and storage, towards the middle
    Flank {
        anchors.left: capsule.right
        anchors.leftMargin: root.groupGap
        loads: rightLoads

        RowLayout {
            id: rightLoads

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.gap

            Load {
                icon: "memory_alt"
                value: Memory.percentage
                text: Strings.percentOne(Memory.percentage)
                widest: Strings.percentOne(1)
            }

            Load {
                icon: "hard_drive"
                value: Storage.primaryDisk?.perc ?? 0
                text: Strings.percentOne(Storage.primaryDisk?.perc ?? 0)
                widest: Strings.percentOne(1)
            }
        }
    }

    // One side of the load. Both are as wide as the wider one, their loads towards
    // the middle; a click opens the dashboard's performance tab.
    component Flank: Item {
        required property Item loads

        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.flankWidth
        implicitHeight: root.size

        opacity: root.showLoad ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        StateLayer {
            anchors.fill: undefined
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            x: parent.loads.x - Tokens.padding.small
            width: parent.loads.width + Tokens.padding.small * 2
            radius: Tokens.rounding.full
            onClicked: root.openDashboard("performance")
        }
    }

    component MediaButton: IconButton {
        type: IconButton.Text
        implicitWidth: implicitHeight
        implicitHeight: root.mediaButtonSize
        font: Tokens.font.icon.medium
        isRound: true
    }

    // One reading: its icon in a ring filled to the value, then the value, in the
    // clock's type and colour. Too hot turns it to the error colour.
    component Load: RowLayout {
        id: load

        required property string icon
        required property real value
        required property string text
        // The widest text it can show, so nothing shifts as the numbers change
        required property string widest
        property bool hot

        readonly property color accent: hot ? Colours.palette.m3error : root.loadColour

        spacing: Tokens.spacing.small

        CircularProgress {
            Layout.alignment: Qt.AlignVCenter
            implicitSize: root.ringSize
            strokeWidth: root.ringStroke
            fgColour: load.accent
            value: load.value
            hasEndIndicator: false // A stray dot at this size

            Behavior on clampedVal {
                Anim {}
            }

            Behavior on fgColour {
                CAnim {}
            }

            MaterialIcon {
                anchors.centerIn: parent
                text: load.icon
                color: load.accent
                fill: 1
                fontStyle: Tokens.font.icon.size(Math.round(root.ringSize * 0.43)).build()
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            Layout.minimumWidth: widestMetrics.width
            text: load.text
            color: load.accent
            font: root.primaryFont

            TextMetrics {
                id: widestMetrics

                font: root.primaryFont
                text: load.widest
            }
        }
    }
}
