pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import QtQml.Models as QtModels
import qs.custom
import Quickshell
import Quickshell.Services.Mpris
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.effects
import qs.services

Item {
    id: root

    required property ScreenState screenState

    readonly property bool hasMedia: !!Players.active && Players.active.trackTitle.length > 0

    readonly property bool isPlaying: Players.active?.isPlaying ?? false

    // Dynamic width calculation based on the widest content
    readonly property real systemWidth: systemLayout.implicitWidth

    readonly property real mediaWidth: mediaLayout.implicitWidth

    // [fork] A bar vastagsága (a hossztengelyére merőlegesen): vízszintesnél a bar
    // magassága, vertikálisnál a szélessége. Rendes bar-elemként a méretet az
    // EntryWrapper az implicit értékekből veszi, ezért kívülről kell megkapnia — a
    // bar adja át. A `height: parent.height` nem járható út, mert a wrapper mérete
    // éppen az elemből jön, az körkörös lenne.
    required property real barThickness

    // [fork] Vertikális barban a vízszintes tartalom (négy metrika egymás mellett,
    // körkörös vizualizáló, cím/előadó) nem fér be egy ~40 px széles sávba. Ezért a
    // pill két külön tartalmat kínál, és a bar dönt: a vízszintes marad az eredeti,
    // a vertikális egy kompakt oszlop — ikon fölött százalék, médiánál borító és
    // egyetlen lejátszás-gomb.
    property bool vertical: false

    readonly property real pillLength: Math.max(vertical ? verticalLayout.implicitHeight : systemWidth, vertical ? 0 : mediaWidth) + Tokens.padding.large * 2

    // A pill elbújik, amíg a dashboard nyitva van — a kettő ugyanazt az
    // információt mutatja, csak más méretben.
    readonly property bool dashOpen: root.screenState.dashboard

    objectName: "miniDash"

    implicitWidth: vertical ? barThickness : pillLength
    implicitHeight: vertical ? pillLength : barThickness

    enabled: !dashOpen
    opacity: dashOpen ? 0 : 1
    scale: dashOpen ? 0.85 : 1

    transform: Translate {
        y: root.dashOpen ? -15 : 0

        Behavior on y {
            Anim {
                type: Anim.DefaultSpatial
            }
        }
    }

    // Auto-switch to media page when music starts playing
    onIsPlayingChanged: {
        if (isPlaying && hasMedia) {
            view.currentIndex = 1; // Media page
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on scale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    ServiceRef {
        service: Audio.cava
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
    ServiceRef {
        service: Gpu
    }

    StyledRect {
        id: bg

        // [fork] Ugyanaz a logika, mint a workspaces pillnél (HWorkspaces.qml):
        // folyamatos módban a pill maga festi a hátterét m3surfaceContainer-rel,
        // szigetes módban viszont a ContentWindow fest alá tömör szigetet, és két
        // réteg egymáson világosabb lenne a bar jobb oldalánál. Szigetes módban
        // ezért a sziget adja a felületet.
        anchors.fill: parent

        color: ExtrasConfig.barIslands ? "transparent" : Colours.tPalette.m3surfaceContainer

        // A nagy dashboardhoz igazodik: a PanelBg is Tokens.rounding.extraLarge-ot
        // használ, így a pill és a kinyíló dashboard formája egy nyelvet beszél.
        radius: Tokens.rounding.extraLarge

        // Swipe View for Pages
        // [fork] Kompakt vertikális tartalom. Egy ~40 px széles sávban a metrika
        // csak egymás alá fér: ikon, alatta a százalék. A hőmérséklet-sor kimarad,
        // mert olvashatatlan méretre kellene zsugorítani — a színkódolás viszont
        // megmarad, tehát a meleg CPU/GPU továbbra is látszik.
        ColumnLayout {
            id: verticalLayout

            anchors.centerIn: parent
            visible: root.vertical
            enabled: root.vertical
            spacing: Tokens.spacing.small

            VMetric {
                icon: "memory"
                value: Cpu.percentage
                colour: Cpu.temperature > 75 ? Colours.palette.m3error : Colours.palette.m3primary
            }
            VMetric {
                icon: "memory_alt"
                value: Memory.percentage
                colour: Colours.palette.m3secondary
            }
            VMetric {
                icon: "hard_drive"
                value: Storage.primaryDisk?.perc ?? 0
                colour: Colours.palette.m3tertiary
            }
            VMetric {
                icon: "videogame_asset"
                value: Gpu.percentage
                colour: Gpu.temperature > 75 ? Colours.palette.m3error : Colours.palette.m3primary
                visible: Gpu.percentage >= 0
            }

            // Média: borító és egyetlen lejátszás-gomb — cím/előadó nem fér ki.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 20
                visible: root.hasMedia
                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
                opacity: 0.2
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasMedia
                implicitWidth: 26
                implicitHeight: 26
                radius: 13
                color: Colours.palette.m3surfaceContainer
                clip: true

                Image {
                    anchors.fill: parent
                    source: Players.getArtUrl(Players.active) || Players.lastArtUrl
                    fillMode: Image.PreserveAspectCrop
                }
            }
            ControlBtn {
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasMedia
                icon: root.isPlaying ? "pause" : "play_arrow"
                enabled: (Players.active?.canTogglePlaying ?? false) && !root.screenState.dashboard
                onClicked: Players.active?.togglePlaying()
            }
        }

        ListView {
            id: view

            visible: !root.vertical
            enabled: !root.vertical

            anchors.fill: parent

            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            clip: true

            boundsBehavior: Flickable.StopAtBounds

            model: QtModels.ObjectModel {
                // PAGE 1: SYSTEM INFO
                Item {
                    width: view.width
                    height: view.height

                    RowLayout {
                        id: systemLayout

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.large

                        // CPU
                        Row {
                            spacing: Tokens.spacing.small
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                text: "memory"
                                color: Colours.palette.m3primary
                                fontStyle.pointSize: 18
                            }
                            Column {
                                spacing: -4

                                StyledText {
                                    text: Math.round(Cpu.percentage * 100) + "%"
                                    font.pointSize: 12
                                    font.bold: true
                                }
                                StyledText {
                                    text: Math.round(Cpu.temperature) + "°C"
                                    font.pointSize: 10
                                    color: Cpu.temperature > 75 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1
                            height: 20
                            color: Colours.palette.m3outlineVariant
                            opacity: 0.2
                        }

                        // RAM
                        Row {
                            spacing: Tokens.spacing.small
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                text: "memory_alt"
                                color: Colours.palette.m3secondary
                                fontStyle.pointSize: 18
                            }
                            Column {
                                spacing: -4

                                StyledText {
                                    text: Math.round(Memory.percentage * 100) + "%"
                                    font.pointSize: 12
                                    font.bold: true
                                }
                                StyledText {
                                    text: (Memory.used / 1024 / 1024).toFixed(1) + "G"
                                    font.pointSize: 10
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1
                            height: 20
                            color: Colours.palette.m3outlineVariant
                            opacity: 0.2
                        }

                        // Disk
                        Row {
                            spacing: Tokens.spacing.small
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                text: "hard_drive"
                                color: Colours.palette.m3tertiary
                                fontStyle.pointSize: 18
                            }
                            Column {
                                spacing: -4

                                StyledText {
                                    text: Math.round((Storage.primaryDisk?.perc ?? 0) * 100) + "%"
                                    font.pointSize: 12
                                    font.bold: true
                                }
                                StyledText {
                                    text: "DISK"
                                    font.pointSize: 10
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1
                            height: 20
                            color: Colours.palette.m3outlineVariant
                            opacity: 0.2
                            visible: Gpu.percentage >= 0
                        }

                        // GPU
                        Row {
                            spacing: Tokens.spacing.small
                            visible: Gpu.percentage >= 0
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                text: "videogame_asset"
                                color: Colours.palette.m3primary
                                fontStyle.pointSize: 18
                            }
                            Column {
                                spacing: -4

                                StyledText {
                                    text: Math.round(Gpu.percentage * 100) + "%"
                                    font.pointSize: 12
                                    font.bold: true
                                }
                                StyledText {
                                    text: Math.round(Gpu.temperature) + "°C"
                                    font.pointSize: 10
                                    color: Gpu.temperature > 75 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }
                }

                // PAGE 2: MEDIA INFO
                Item {
                    width: view.width
                    height: view.height

                    StyledText {
                        anchors.centerIn: parent
                        text: qsTr("No media playing")
                        visible: !root.hasMedia
                        color: Colours.palette.m3onSurfaceVariant
                        font.italic: true
                    }

                    RowLayout {
                        id: mediaLayout

                        anchors.centerIn: parent
                        spacing: Tokens.spacing.medium
                        visible: root.hasMedia

                        Item {
                            implicitWidth: 46
                            implicitHeight: 46

                            Shape {
                                id: visualiser

                                anchors.fill: parent
                                anchors.margins: -4

                                readonly property real centerX: width / 2

                                readonly property real centerY: height / 2

                                readonly property real innerR: cover.width / 2 + 2
                                preferredRendererType: Shape.CurveRenderer
                                data: visualiserBars.instances
                            }
                            Variants {
                                id: visualiserBars

                                model: Array.from({
                                    length: GlobalConfig.services.visualiserBars
                                }, (_, i) => i)

                                ShapePath {
                                    id: visualiserBar

                                    required property int modelData
                                    readonly property real value: Math.max(0.1, Math.min(1, Audio.cava.values[modelData] || 0))
                                    readonly property real angle: modelData * 2 * Math.PI / GlobalConfig.services.visualiserBars
                                    readonly property real magnitude: value * 8
                                    readonly property real cos: Math.cos(angle)
                                    readonly property real sin: Math.sin(angle)

                                    strokeWidth: 2.2
                                    strokeColor: Colours.palette.m3primary
                                    capStyle: ShapePath.RoundCap
                                    fillColor: "transparent"
                                    startX: visualiser.centerX + visualiser.innerR * cos
                                    startY: visualiser.centerY + visualiser.innerR * sin

                                    PathLine {
                                        x: visualiser.centerX + (visualiser.innerR + visualiserBar.magnitude) * visualiserBar.cos
                                        y: visualiser.centerY + (visualiser.innerR + visualiserBar.magnitude) * visualiserBar.sin
                                    }
                                    Behavior on strokeColor {
                                        CAnim {}
                                    }
                                }
                            }
                            StyledClippingRect {
                                id: cover

                                anchors.centerIn: parent
                                width: 34
                                height: 34
                                radius: 17
                                color: Colours.palette.m3surfaceContainer

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    font.pointSize: 14
                                    color: Colours.palette.m3onSurfaceVariant
                                    visible: image.status != Image.Ready
                                }
                                Image {
                                    id: image

                                    anchors.fill: parent
                                    source: Players.getArtUrl(Players.active) || Players.lastArtUrl
                                    fillMode: Image.PreserveAspectCrop
                                }
                            }
                        }

                        Column {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 160
                            spacing: -2

                            StyledText {
                                width: parent.width
                                text: (Players.active?.trackTitle || "")
                                font.pointSize: 13
                                font.weight: 600
                                elide: Text.ElideRight
                                color: Colours.palette.m3primary
                            }
                            StyledText {
                                width: parent.width
                                text: (Players.active?.trackArtist || "")
                                font.pointSize: 11
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurfaceVariant
                                visible: text.length > 0
                            }
                        }

                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter

                            ControlBtn {
                                icon: "skip_previous"
                                onClicked: Players.active?.previous()
                                enabled: (Players.active?.canGoPrevious ?? false) && !root.screenState.dashboard
                            }
                            ControlBtn {
                                icon: root.isPlaying ? "pause" : "play_arrow"
                                onClicked: Players.active?.togglePlaying()
                                enabled: (Players.active?.canTogglePlaying ?? false) && !root.screenState.dashboard
                            }
                            ControlBtn {
                                icon: "skip_next"
                                onClicked: Players.active?.next()
                                enabled: (Players.active?.canGoNext ?? false) && !root.screenState.dashboard
                            }
                        }
                    }
                }
            }
        }
    }

    // [fork] Egy metrika a kompakt vertikális változatban: ikon, alatta a százalék.
    component VMetric: ColumnLayout {
        id: metric

        required property string icon
        required property real value
        required property color colour

        Layout.alignment: Qt.AlignHCenter
        spacing: -2

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: metric.icon
            color: metric.colour
            fontStyle.pointSize: 15
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `${Math.round(metric.value * 100)}%`
            color: metric.colour
            font.pointSize: 9
            font.bold: true
        }
    }

    component ControlBtn: Item {
        id: btn

        required property string icon

        signal clicked

        implicitWidth: 38
        implicitHeight: 38
        opacity: enabled ? 1 : 0.3

        StateLayer {
            anchors.fill: parent
            radius: width / 2
            onClicked: btn.clicked()
        }
        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            fontStyle.pointSize: 20
            color: Colours.palette.m3onSurface
        }
    }
}
