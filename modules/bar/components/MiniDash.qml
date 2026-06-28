pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import Caelestia.Config
import Quickshell
import Caelestia.Services
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Controls
import QtQml.Models

Item {
    id: root
    objectName: "miniDash"

    required property DrawerVisibilities visibilities

    readonly property bool hasMedia: !!Players.active && Players.active.trackTitle.length > 0
    readonly property bool isPlaying: Players.active?.isPlaying ?? false

    readonly property int barPadding: Math.max(Tokens.padding.smaller, Config.border.thickness)

    // Dynamic width calculation based on the widest content
    readonly property real systemWidth: systemLayout.implicitWidth
    readonly property real mediaWidth: mediaLayout.implicitWidth
    readonly property real pillWidth: Math.max(systemWidth, mediaWidth) + Tokens.padding.large * 2

    implicitWidth: pillWidth
    height: parent.height

    Component.onCompleted: {}
    Component.onDestruction: {}

    ServiceRef {
        service: Audio.cava
    }

    ServiceRef { service: Cpu }
    ServiceRef { service: Memory }
    ServiceRef { service: Storage }
    ServiceRef { service: Gpu }

    // Auto-switch to media page when music starts playing
    onIsPlayingChanged: {
        if (isPlaying && hasMedia) {
            view.currentIndex = 1; // Media page
        }
    }

    StyledRect {
        id: bg
        anchors.fill: parent
        anchors.topMargin: -root.barPadding
        anchors.bottomMargin: 0

        color: Colours.tPalette.m3surface

        topLeftRadius: Config.border.rounding
        topRightRadius: Config.border.rounding
        bottomLeftRadius: Config.border.rounding
        bottomRightRadius: Config.border.rounding

        // Swipe View for Pages
        ListView {
            id: view
            anchors.fill: parent

            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            clip: true

            boundsBehavior: Flickable.StopAtBounds

            model: ObjectModel {
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
                            MaterialIcon { text: "memory"; color: Colours.palette.m3primary; fontStyle.pointSize: 18 }
                            Column {
                                spacing: -4
                                StyledText { text: Math.round(Cpu.percentage * 100) + "%"; font.pointSize: 12; font.bold: true }
                                StyledText { text: Math.round(Cpu.temperature) + "°C"; font.pointSize: 10; color: Cpu.temperature > 75 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant }
                            }
                        }

                        Rectangle { Layout.alignment: Qt.AlignVCenter; width: 1; height: 20; color: Colours.palette.m3outlineVariant; opacity: 0.2 }

                        // RAM
                        Row {
                            spacing: Tokens.spacing.small
                            Layout.alignment: Qt.AlignVCenter
                            MaterialIcon { text: "memory_alt"; color: Colours.palette.m3secondary; fontStyle.pointSize: 18 }
                            Column {
                                spacing: -4
                                StyledText { text: Math.round(Memory.percentage * 100) + "%"; font.pointSize: 12; font.bold: true }
                                StyledText { text: (Memory.used / 1024 / 1024).toFixed(1) + "G"; font.pointSize: 10; color: Colours.palette.m3onSurfaceVariant }
                            }
                        }

                        Rectangle { Layout.alignment: Qt.AlignVCenter; width: 1; height: 20; color: Colours.palette.m3outlineVariant; opacity: 0.2 }

                        // Disk
                        Row {
                            spacing: Tokens.spacing.small
                            Layout.alignment: Qt.AlignVCenter
                            MaterialIcon { text: "hard_drive"; color: Colours.palette.m3tertiary; fontStyle.pointSize: 18 }
                            Column {
                                spacing: -4
                                StyledText { text: Math.round((Storage.primaryDisk?.perc ?? 0) * 100) + "%"; font.pointSize: 12; font.bold: true }
                                StyledText { text: "DISK"; font.pointSize: 10; color: Colours.palette.m3onSurfaceVariant }
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignVCenter
                            width: 1; height: 20; color: Colours.palette.m3outlineVariant; opacity: 0.2
                            visible: Gpu.percentage >= 0
                        }

                        // GPU
                        Row {
                            spacing: Tokens.spacing.small
                            visible: Gpu.percentage >= 0
                            Layout.alignment: Qt.AlignVCenter

                            MaterialIcon { text: "videogame_asset"; color: Colours.palette.m3primary; fontStyle.pointSize: 18 }
                            Column {
                                spacing: -4
                                StyledText { text: Math.round(Gpu.percentage * 100) + "%"; font.pointSize: 12; font.bold: true }
                                StyledText { text: Math.round(Gpu.temperature) + "°C"; font.pointSize: 10; color: Gpu.temperature > 75 ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant }
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
                            implicitWidth: 46; implicitHeight: 46
                            Shape {
                                id: visualiser
                                anchors.fill: parent; anchors.margins: -4
                                readonly property real centerX: width / 2; readonly property real centerY: height / 2; readonly property real innerR: cover.width / 2 + 2
                                preferredRendererType: Shape.CurveRenderer
                                data: visualiserBars.instances
                            }
                            Variants {
                                id: visualiserBars
                                model: Array.from({ length: GlobalConfig.services.visualiserBars }, (_, i) => i)
                                ShapePath {
                                    id: visualiserBar
                                    required property int modelData
                                    readonly property real value: Math.max(0.1, Math.min(1, Audio.cava.values[modelData] || 0))
                                    readonly property real angle: modelData * 2 * Math.PI / GlobalConfig.services.visualiserBars
                                    readonly property real magnitude: value * 8
                                    readonly property real cos: Math.cos(angle); readonly property real sin: Math.sin(angle)
                                    strokeWidth: 2.2; strokeColor: Colours.palette.m3primary; capStyle: ShapePath.RoundCap; fillColor: "transparent"
                                    startX: visualiser.centerX + visualiser.innerR * cos; startY: visualiser.centerY + visualiser.innerR * sin
                                    PathLine { x: visualiser.centerX + (visualiser.innerR + visualiserBar.magnitude) * visualiserBar.cos; y: visualiser.centerY + (visualiser.innerR + visualiserBar.magnitude) * visualiserBar.sin }
                                    Behavior on strokeColor { CAnim {} }
                                }
                            }
                            StyledClippingRect {
                                id: cover; anchors.centerIn: parent; width: 34; height: 34; radius: 17; color: Colours.palette.m3surfaceContainer
                                MaterialIcon {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    font.pointSize: 14
                                    color: Colours.palette.m3onSurfaceVariant
                                    visible: image.status != Image.Ready
                                }
                                Image { id: image; anchors.fill: parent; source: (Players.active?.trackArtUrl || Players.lastArtUrl) ?? ""; fillMode: Image.PreserveAspectCrop }
                            }
                        }

                        Column {
                            Layout.alignment: Qt.AlignVCenter; Layout.preferredWidth: 160; spacing: -2
                            StyledText { width: parent.width; text: (Players.active?.trackTitle || ""); font.pointSize: 13; font.weight: 600; elide: Text.ElideRight; color: Colours.palette.m3primary }
                            StyledText { width: parent.width; text: (Players.active?.trackArtist || ""); font.pointSize: 11; elide: Text.ElideRight; color: Colours.palette.m3onSurfaceVariant; visible: text.length > 0 }
                        }

                        Row {
                            spacing: 4; Layout.alignment: Qt.AlignVCenter
                            ControlBtn { icon: "skip_previous"; onClicked: Players.active?.previous(); enabled: (Players.active?.canGoPrevious ?? false) && !root.visibilities.dashboard }
                            ControlBtn { icon: root.isPlaying ? "pause" : "play_arrow"; onClicked: Players.active?.togglePlaying(); enabled: (Players.active?.canTogglePlaying ?? false) && !root.visibilities.dashboard }
                            ControlBtn { icon: "skip_next"; onClicked: Players.active?.next(); enabled: (Players.active?.canGoNext ?? false) && !root.visibilities.dashboard }
                        }
                    }
                }
            }
        }
    }

    component ControlBtn: Item {
        id: btn; required property string icon; signal clicked()
        implicitWidth: 38; implicitHeight: 38
        opacity: enabled ? 1 : 0.3
        StateLayer { anchors.fill: parent; radius: width / 2; onClicked: btn.clicked() }
        MaterialIcon { anchors.centerIn: parent; text: btn.icon; fontStyle.pointSize: 20; color: Colours.palette.m3onSurface }
    }

    // Fixed animations for open/close
    readonly property bool dashOpen: root.visibilities.dashboard
    enabled: !dashOpen
    opacity: dashOpen ? 0 : 1
    scale: dashOpen ? 0.85 : 1
    transform: Translate { y: dashOpen ? -15 : 0; Behavior on y { Anim { type: Anim.DefaultSpatial } } }
    Behavior on opacity { Anim { type: Anim.DefaultSpatial } }
    Behavior on scale { Anim { type: Anim.DefaultSpatial } }
}
