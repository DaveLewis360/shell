import "media"
import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    required property DrawerVisibilities visibilities

    implicitWidth: Tokens.sizes.dashboard.mediaTabWidth
    implicitHeight: Tokens.sizes.dashboard.mediaTabHeight

    property bool lyricMenuOpen: false
    property bool lyricsShowing: LyricsService.lyricsVisible && LyricsService.model.count != 0
    property bool lyricsShowingDebounced: false

    property real playerProgress: {
        const active = Players.active;
        return active?.length ? (active.position % active.length) / active.length : 0;
    }

    function lengthStr(length: int): string {
        if (length < 0)
            return "-1:-1";

        const hours = Math.floor(length / 3600);
        const mins = Math.floor((length % 3600) / 60);
        const secs = Math.floor(length % 60).toString().padStart(2, "0");

        if (hours > 0)
            return `${hours}:${mins.toString().padStart(2, "0")}:${secs}`;
        return `${mins}:${secs}`;
    }

    onLyricsShowingChanged: {
        if (lyricsShowing) {
            lyricsHideDelay.stop();
            lyricsShowingDebounced = true;
        } else {
            lyricsHideDelay.restart();
        }
    }

    implicitWidth: cover.implicitWidth + Tokens.sizes.dashboard.mediaVisualiserSize * 2 + details.implicitWidth + details.anchors.leftMargin + bongocat.implicitWidth + bongocat.anchors.leftMargin * 2 + Tokens.padding.large * 2
    implicitHeight: nonAnimHeight

    Behavior on implicitHeight {
        Anim {}
    }

    Behavior on playerProgress {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Timer {
        running: Players.active?.isPlaying ?? false
        interval: GlobalConfig.dashboard.mediaUpdateInterval
        triggeredOnStart: true
        repeat: true
        onTriggered: {
            if (!Players.active)
                return;
            LyricsService.updatePosition();
            Players.active?.positionChanged();
        }
    }

    Timer {
        id: lyricsHideDelay

        interval: 300
        repeat: false
    }

    Connections {
        function onTriggered() {
            root.lyricsShowingDebounced = false;
        }

        target: lyricsHideDelay
    }

    ServiceRef {
        service: Audio.cava
    }

    ServiceRef {
        service: Audio.beatTracker
    }

    Shape {
        id: visualiser

        readonly property real centerX: width / 2
        readonly property real centerY: height / 2
        readonly property real innerX: cover.implicitWidth / 2 + Tokens.spacing.small
        readonly property real innerY: cover.implicitHeight / 2 + Tokens.spacing.small
        property color colour: Colours.palette.m3primary

        anchors.fill: cover
        anchors.margins: -Tokens.sizes.dashboard.mediaVisualiserSize

        asynchronous: true
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
            readonly property real value: Math.max(1e-3, Math.min(1, Audio.cava.values[modelData]))

            readonly property real angle: modelData * 2 * Math.PI / GlobalConfig.services.visualiserBars
            readonly property real magnitude: value * root.Tokens.sizes.dashboard.mediaVisualiserSize
            readonly property real cos: Math.cos(angle)
            readonly property real sin: Math.sin(angle)

            capStyle: root.Tokens.rounding.scale === 0 ? ShapePath.SquareCap : ShapePath.RoundCap
            strokeWidth: 360 / GlobalConfig.services.visualiserBars - root.Tokens.spacing.small / 4
            strokeColor: Colours.palette.m3primary

            startX: visualiser.centerX + (visualiser.innerX + strokeWidth / 2) * cos
            startY: visualiser.centerY + (visualiser.innerY + strokeWidth / 2) * sin

            PathLine {
                x: visualiser.centerX + (visualiser.innerX + visualiserBar.strokeWidth / 2 + visualiserBar.magnitude) * visualiserBar.cos
                y: visualiser.centerY + (visualiser.innerY + visualiserBar.strokeWidth / 2 + visualiserBar.magnitude) * visualiserBar.sin
            }

            Behavior on strokeColor {
                CAnim {}
            }
        }
    }

    StyledClippingRect {
        id: cover

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Tokens.padding.large + Tokens.sizes.dashboard.mediaVisualiserSize

        implicitWidth: Tokens.sizes.dashboard.mediaCoverArtSize
        implicitHeight: Tokens.sizes.dashboard.mediaCoverArtSize

        color: Colours.tPalette.m3surfaceContainerHigh
        radius: Infinity

        MaterialIcon {
            anchors.centerIn: parent

            grade: 200
            text: "art_track"
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: (parent.width * 0.4) || 1
        }

        Image {
            id: image

            anchors.fill: parent

            source: (Players.active?.trackArtUrl || Players.lastArtUrl) ?? ""
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize: {
                const dpr = (QsWindow.window as QsWindow)?.devicePixelRatio ?? 1;
                return Qt.size(width * dpr, height * dpr);
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    LyricsService.toggleVisibility();
                }
            }
        }
    }

    ColumnLayout {
        id: details

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: visualiser.right
        anchors.leftMargin: Tokens.spacing.normal

        spacing: Tokens.spacing.small

        StyledText {
            id: title

            Layout.fillWidth: true
            Layout.maximumWidth: parent.implicitWidth

            animate: true
            horizontalAlignment: Text.AlignHCenter
            text: (Players.active?.trackTitle ?? qsTr("No media")) || qsTr("Unknown title")
            color: Players.active ? Colours.palette.m3primary : Colours.palette.m3onSurface
            font.pointSize: Tokens.font.size.normal
            elide: Text.ElideRight
        }

        StyledText {
            id: album

            Layout.fillWidth: true
            Layout.maximumWidth: parent.implicitWidth

            animate: true
            horizontalAlignment: Text.AlignHCenter
            visible: !!Players.active
            text: Players.active?.trackAlbum || qsTr("Unknown album")
            color: Colours.palette.m3outline
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
        }

        StyledText {
            id: artist

            Layout.fillWidth: true
            Layout.maximumWidth: parent.implicitWidth

            animate: true
            horizontalAlignment: Text.AlignHCenter
            text: (Players.active?.trackArtist ?? qsTr("Play some music for stuff to show up here!")) || qsTr("Unknown artist")
            color: Players.active ? Colours.palette.m3secondary : Colours.palette.m3outline
            elide: Text.ElideRight
            wrapMode: Players.active ? Text.NoWrap : Text.WordWrap
        }

        LyricsView {
            id: lyricsViewInDetails

            Layout.fillWidth: true
            Layout.preferredHeight: 200
        }

        RowLayout {
            id: controls

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.small
            Layout.bottomMargin: Tokens.spacing.smaller

            spacing: Tokens.spacing.small

            PlayerControl {
                type: IconButton.Text
                icon: Players.active?.shuffle ? "shuffle_on" : "shuffle"
                font.pointSize: Math.round(Tokens.font.size.large)
                disabled: !Players.active?.shuffleSupported
                onClicked: Players.active.shuffle = !Players.active?.shuffle
            }

            PlayerControl {
                type: IconButton.Text
                icon: "skip_previous"
                font.pointSize: Math.round(Tokens.font.size.large * 1.5)
                disabled: !Players.active?.canGoPrevious
                onClicked: Players.active?.previous()
            }

            PlayerControl {
                icon: Players.active?.isPlaying ? "pause" : "play_arrow"
                label.animate: true
                toggle: true
                padding: Tokens.padding.small / 2
                checked: Players.active?.isPlaying ?? false
                font.pointSize: Math.round(Tokens.font.size.large * 1.5)
                disabled: !Players.active?.canTogglePlaying
                onClicked: Players.active?.togglePlaying()
            }

            PlayerControl {
                type: IconButton.Text
                icon: "skip_next"
                font.pointSize: Math.round(Tokens.font.size.large * 1.5)
                disabled: !Players.active?.canGoNext
                onClicked: Players.active?.next()
            }

            PlayerControl {
                type: IconButton.Text
                icon: "lyrics"
                font.pointSize: Math.round(Tokens.font.size.large)
                onClicked: root.lyricMenuOpen = !root.lyricMenuOpen
            }
        }

        StyledSlider {
            id: slider

            enabled: !!Players.active
            implicitWidth: 280
            implicitHeight: Tokens.padding.normal * 3

            onMoved: {
                const active = Players.active;
                if (active?.canSeek && active?.positionSupported)
                    active.position = value * active.length;
            }

            Binding {
                target: slider
                property: "value"
                value: root.playerProgress
                when: !slider.pressed
            }

            CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    const active = Players.active;
                    if (!active?.canSeek || !active?.positionSupported)
                        return;

                    event.accepted = true;
                    const delta = event.angleDelta.y > 0 ? 10 : -10;    // Time 10 seconds
                    Qt.callLater(() => {
                        active.position = Math.max(0, Math.min(active.length, active.position + delta));
                    });
                }

                anchors.fill: parent
                acceptedButtons: Qt.NoButton
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(position.implicitHeight, length.implicitHeight)

            StyledText {
                id: position

                anchors.left: parent.left

                text: root.lengthStr(Players.active ? Players.active.position % Players.active.length : -1)
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }

            StyledText {
                id: length

                anchors.right: parent.right

                text: root.lengthStr(Players.active?.length ?? -1)
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: Tokens.font.size.small
            }
        }
    }

    ColumnLayout {
        id: leftSection

        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: playerChanger.parent == leftSection ? -playerChanger.height : 0
        anchors.left: details.right
        anchors.leftMargin: Tokens.spacing.normal

        visible: lyricMenu.height === 0 || opacity > 0
        opacity: lyricMenu.height === 0 ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.anim.durations.normal
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: bongocat

            implicitWidth: visualiser.width
            implicitHeight: visualiser.height

            AnimatedImage {
                anchors.centerIn: parent

                width: visualiser.width * 0.75
                height: visualiser.height * 0.75

                playing: Players.active?.isPlaying ?? false
                speed: Audio.beatTracker.bpm / Config.general.mediaGifSpeedAdjustment // qmllint disable unresolved-type
                source: Paths.absolutePath(Config.paths.mediaGif)
                asynchronous: true
                fillMode: AnimatedImage.PreserveAspectFit
            }
        }
    }

    LyricMenu {
        id: lyricMenu

        anchors.top: parent.top
        anchors.left: details.right
        anchors.right: parent.right
        anchors.leftMargin: Tokens.spacing.normal

        contentHeight: !root.lyricsShowingDebounced ? root.detailsHeightWithoutLyrics + Tokens.padding.large * 5 : root.detailsHeightWithoutLyrics + lyricsViewInDetails.implicitHeight

        visible: root.lyricMenuOpen || height > 0
        height: root.lyricMenuOpen ? implicitHeight : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Tokens.anim.durations.normal
                easing.type: Easing.OutCubic
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.extraLarge

        CoverVisualiser {
            Layout.fillHeight: true
            implicitWidth: Tokens.sizes.dashboard.mediaSectionWidth
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            state: Players.active ? "" : "noMedia"

            states: State {
                name: "noMedia"

                PropertyChanges {
                    noMedia.opacity: 1
                    content.opacity: 0
                }
            }

            transitions: [
                Transition {
                    from: ""

                    SequentialAnimation {
                        Anim {
                            target: content
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                        Anim {
                            target: noMedia
                            property: "opacity"
                            type: Anim.SlowEffects
                        }
                    }
                },
                Transition {
                    to: ""

                    SequentialAnimation {
                        Anim {
                            target: noMedia
                            property: "opacity"
                            type: Anim.DefaultEffects
                        }
                        Anim {
                            target: content
                            property: "opacity"
                            type: Anim.SlowEffects
                        }
                    }
                }
            ]

            Loader {
                id: noMedia

                anchors.centerIn: parent
                anchors.horizontalCenterOffset: -Tokens.padding.extraLarge * 2
                asynchronous: true
                active: opacity > 0
                opacity: 0

                sourceComponent: ColumnLayout {
                    spacing: Tokens.spacing.small

                    MaterialShape {
                        Layout.topMargin: (pathBounds().height - implicitSize) / 2
                        Layout.bottomMargin: (pathBounds().height - implicitSize) / 2 + Tokens.spacing.small
                        Layout.alignment: Qt.AlignHCenter
                        color: Colours.palette.m3primaryContainer
                        implicitSize: icon.implicitHeight + Tokens.padding.extraLarge * 2
                        shape: MaterialShape.ClamShell

                        Behavior on color {
                            CAnim {}
                        }

                        MaterialIcon {
                            id: icon

                            anchors.centerIn: parent
                            text: "queue_music"
                            fontStyle: Tokens.font.icon.builders.large.scale(2).build()
                            color: Colours.palette.m3onPrimaryContainer
                        }
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Nothing playing")
                        font: Tokens.font.headline.medium
                    }

                    StyledText {
                        text: qsTr("Play something for it to show up here!")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.large
                    }
                }
            }

            Loader {
                id: content

                anchors.fill: parent
                asynchronous: true
                active: opacity > 0

                sourceComponent: RowLayout {
                    spacing: Tokens.spacing.extraLarge

                    Details {
                        Layout.fillWidth: true
                    }

                    LyricsAndSelector {
                        Layout.fillHeight: true
                        implicitWidth: Tokens.sizes.dashboard.mediaSectionWidth
                    }
                }
            }
        }
    }
}
