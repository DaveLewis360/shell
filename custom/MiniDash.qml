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

    // [fork] Származtatott méretek. Korábban itt kézzel beírt pixelértékek voltak
    // (34, 46, 38, 160, 26, 20), amik nem követték a felhasználó token-beállításait
    // és nem illeszkedtek a szomszédos elemekhez. Mindegyik a bar belső méretéből
    // és a térköz-skálából jön, egyetlen helyen.
    readonly property real coverSize: Tokens.sizes.bar.innerWidth - Tokens.spacing.small
    readonly property real visualiserSize: coverSize + Tokens.spacing.medium
    readonly property real btnSize: Tokens.sizes.bar.innerWidth
    readonly property real mediaTextWidth: Tokens.sizes.bar.innerWidth * 4
    readonly property real vCoverSize: Tokens.sizes.bar.innerWidth - Tokens.padding.medium
    readonly property real separatorLength: Tokens.sizes.bar.innerWidth / 2

    // Egyetlen forrás a hőmérséklet-figyelmeztetéshez, négy ismételt 75 helyett.
    readonly property real tempWarnC: 75

    // A halvány elválasztó vonalak áttetszősége — egy helyen, hogy egységes legyen.
    readonly property real separatorOpacity: 0.2

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

        // A dashboard extraLarge (28) rádiuszt használ, de az egy nagy panelen
        // arányos — egy ~40 px magas pillen ugyanaz már majdnem kapszula, és
        // túl hangosan szól. A `large` (16) ugyanabból a skálából jön, csak a
        // méretünkhöz illő fokon.
        radius: Tokens.rounding.large

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
                colour: Cpu.temperature > root.tempWarnC ? Colours.palette.m3error : Colours.palette.m3primary
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
                colour: Gpu.temperature > root.tempWarnC ? Colours.palette.m3error : Colours.palette.m3primary
                visible: Gpu.percentage >= 0
            }

            // Média: borító és egyetlen lejátszás-gomb — cím/előadó nem fér ki.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.separatorLength
                visible: root.hasMedia
                implicitHeight: 1
                color: Colours.palette.m3outlineVariant
                opacity: root.separatorOpacity
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                visible: root.hasMedia
                implicitWidth: root.vCoverSize
                implicitHeight: root.vCoverSize
                radius: root.vCoverSize / 2
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
                                fontStyle: Tokens.font.icon.medium
                            }
                            Column {
                                spacing: -Tokens.spacing.extraSmall

                                StyledText {
                                    text: Math.round(Cpu.percentage * 100) + "%"
                                    font: Tokens.font.mono.builders.medium.weight(Font.Bold).build()
                                }
                                StyledText {
                                    text: Math.round(Cpu.temperature) + "°C"
                                    font: Tokens.font.mono.small
                                    color: Cpu.temperature > root.tempWarnC ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1 // hajszálvonal
                            height: root.separatorLength
                            color: Colours.palette.m3outlineVariant
                            opacity: root.separatorOpacity
                        }

                        // RAM
                        Row {
                            spacing: Tokens.spacing.small
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                text: "memory_alt"
                                color: Colours.palette.m3secondary
                                fontStyle: Tokens.font.icon.medium
                            }
                            Column {
                                spacing: -Tokens.spacing.extraSmall

                                StyledText {
                                    text: Math.round(Memory.percentage * 100) + "%"
                                    font: Tokens.font.mono.builders.medium.weight(Font.Bold).build()
                                }
                                StyledText {
                                    text: (Memory.used / 1024 / 1024).toFixed(1) + "G"
                                    font: Tokens.font.mono.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1 // hajszálvonal
                            height: root.separatorLength
                            color: Colours.palette.m3outlineVariant
                            opacity: root.separatorOpacity
                        }

                        // Disk
                        Row {
                            spacing: Tokens.spacing.small
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon {
                                text: "hard_drive"
                                color: Colours.palette.m3tertiary
                                fontStyle: Tokens.font.icon.medium
                            }
                            Column {
                                spacing: -Tokens.spacing.extraSmall

                                StyledText {
                                    text: Math.round((Storage.primaryDisk?.perc ?? 0) * 100) + "%"
                                    font: Tokens.font.mono.builders.medium.weight(Font.Bold).build()
                                }
                                StyledText {
                                    text: "DISK"
                                    font: Tokens.font.mono.small
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1 // hajszálvonal
                            height: root.separatorLength
                            color: Colours.palette.m3outlineVariant
                            opacity: root.separatorOpacity
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
                                fontStyle: Tokens.font.icon.medium
                            }
                            Column {
                                spacing: -Tokens.spacing.extraSmall

                                StyledText {
                                    text: Math.round(Gpu.percentage * 100) + "%"
                                    font: Tokens.font.mono.builders.medium.weight(Font.Bold).build()
                                }
                                StyledText {
                                    text: Math.round(Gpu.temperature) + "°C"
                                    font: Tokens.font.mono.small
                                    color: Gpu.temperature > root.tempWarnC ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
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
                            implicitWidth: root.visualiserSize
                            implicitHeight: root.visualiserSize

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
                                width: root.coverSize
                                height: root.coverSize
                                radius: root.coverSize / 2
                                color: Colours.palette.m3surfaceContainer

                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    font: Tokens.font.body.medium
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
                            Layout.preferredWidth: root.mediaTextWidth
                            spacing: -Tokens.spacing.extraSmall / 2

                            StyledText {
                                width: parent.width
                                text: (Players.active?.trackTitle || "")
                                font: Tokens.font.body.builders.medium.weight(Font.DemiBold).build()
                                elide: Text.ElideRight
                                color: Colours.palette.m3primary
                            }
                            StyledText {
                                width: parent.width
                                text: (Players.active?.trackArtist || "")
                                font: Tokens.font.body.small
                                elide: Text.ElideRight
                                color: Colours.palette.m3onSurfaceVariant
                                visible: text.length > 0
                            }
                        }

                        Row {
                            spacing: Tokens.spacing.extraSmall
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
        spacing: -Tokens.spacing.extraSmall / 2

        MaterialIcon {
            Layout.alignment: Qt.AlignHCenter
            text: metric.icon
            color: metric.colour
            fontStyle: Tokens.font.icon.small
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: `${Math.round(metric.value * 100)}%`
            color: metric.colour
            font: Tokens.font.mono.builders.small.weight(Font.Bold).build()
        }
    }

    component ControlBtn: Item {
        id: btn

        required property string icon

        signal clicked

        implicitWidth: root.btnSize
        implicitHeight: root.btnSize
        opacity: enabled ? 1 : 0.3

        StateLayer {
            anchors.fill: parent
            radius: width / 2
            onClicked: btn.clicked()
        }
        MaterialIcon {
            anchors.centerIn: parent
            text: btn.icon
            fontStyle: Tokens.font.icon.medium
            color: Colours.palette.m3onSurface
        }
    }
}
