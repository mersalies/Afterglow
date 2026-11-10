import QtQuick
import Quickshell
import Quickshell.Wayland

// The application window: the showcase layout (clock, cover carousel,
// library, lyrics, transport bar), or a mini row when the window is short.
FloatingWindow {
    id: win

    title: "Afterglow"
    implicitWidth: 1400
    implicitHeight: 860
    minimumSize: Qt.size(340, 150)
    color: "transparent"
    onClosed: Qt.quit()

    BackgroundEffect.blurRegion: Region { item: root }

    readonly property bool compact: height < 280
    readonly property real glass: Math.max(0, Math.min(1, Config.glassOpacity))
    readonly property bool wide: !compact && width >= 780
    readonly property bool lyricsOn: Config.showLyrics

    Item {
        id: root
        anchors.fill: parent
        focus: true
        clip: true

        HoverHandler { id: windowHover }

        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (e.key === Qt.Key_Escape) { menu.open = false; styleMenu.open = false; glowMenu.open = false; settingsMenu.open = false; builder.hide(); }
            else if (e.key === Qt.Key_Space) Player.toggle();
            else if (e.key === Qt.Key_Right && ctrl) Player.next();
            else if (e.key === Qt.Key_Left && ctrl) Player.previous();
            else if (e.key === Qt.Key_Right && Player.canSeek) Player.setPosition(Player.position + 5);
            else if (e.key === Qt.Key_Left && Player.canSeek) Player.setPosition(Player.position - 5);
            else if (e.key === Qt.Key_L) Config.showLyrics = !Config.showLyrics;
            else if (e.key === Qt.Key_G) Config.glowEnabled = !Config.glowEnabled;
            else if (e.key === Qt.Key_B) Config.showLibrary = !Config.showLibrary;
            else if (e.key === Qt.Key_C) Config.videoBackground = !Config.videoBackground;
            else if (e.key === Qt.Key_S) {
                const order = ["auto", "fly", "extrude", "crumble", "wave", "glitch", "neon", "bounce"];
                Config.lyricsStyle = order[(order.indexOf(Config.lyricsStyle) + 1) % order.length];
                Spotify.say("Анимация: " + styleMenu.entries.find(x => x[0] === Config.lyricsStyle)[1]);
            }
            else if (e.key === Qt.Key_Q || e.key === Qt.Key_Slash) builder.show("");
            else if (e.key === Qt.Key_V) Config.view = Config.view === "covers" ? "lyrics" : "covers";
            else return;
            e.accepted = true;
        }

        // ---- Field: smoked glass lit by the blurred cover

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.03, 0.03, 0.05, 0.72 * win.glass)
        }

        CrossfadeImage {
            id: backdrop
            anchors.centerIn: parent
            width: Math.max(parent.width, parent.height) * 1.2
            height: width
            // Unloaded while the sharp cover or a clip covers the field.
            source: video.showing || coverBackdrop.showing ? "" : (Player.localArt || Player.artUrl)
            blurAmount: 1
            brightness: -0.35
            sourceSize: 256
            opacity: 0.55 * win.glass

            SequentialAnimation on rotation {
                loops: Animation.Infinite
                running: Player.isPlaying
                NumberAnimation { from: -6; to: 6; duration: 40000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 6; to: -6; duration: 40000; easing.type: Easing.InOutSine }
            }
        }

        // No clip (or clips off): the cover itself, sharp and slowly drifting.
        CrossfadeImage {
            id: coverBackdrop
            readonly property bool showing: !video.showing && source !== ""
            anchors.fill: parent
            source: Player.localArt || Player.artUrl
            sourceSize: 768
            blurAmount: Math.max(0, Math.min(1, Config.backdropBlur))
            brightness: -0.12
            opacity: showing ? 0.92 * Config.backdropOpacity : 0
            Behavior on opacity { NumberAnimation { duration: 900 } }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: coverBackdrop.showing && Player.isPlaying
                NumberAnimation { from: 1.04; to: 1.14; duration: 30000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.14; to: 1.04; duration: 30000; easing.type: Easing.InOutSine }
            }
        }

        VideoBackdrop {
            id: video
            anchors.fill: parent
        }

        // Tint the field with the cover; much lighter over a clip so the footage shows.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(Player.tint.r, Player.tint.g, Player.tint.b, (video.showing ? 0.22 : coverBackdrop.showing ? 0.3 : 0.6) * win.glass)
            Behavior on color { ColorAnimation { duration: Theme.slow * 2 } }
        }

        // Window-wide hairline edge.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Theme.hairline
        }

        // Drag anywhere on the empty field to move a floating window.
        MouseArea {
            anchors.fill: parent
            onPressed: win.startSystemMove()
            // Swallow stray wheel events (volume lives on the transport bar only).
            onWheel: e => e.accepted = true
        }

        Spectrum {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 0
            height: win.compact ? 24 : 56
            barGap: 3
            opacity: 0.32
            visible: Player.hasPlayer
        }

        // ---- Empty state

        Column {
            anchors.centerIn: parent
            spacing: 12
            visible: !Player.hasPlayer && win.compact
            width: Math.min(parent.width - 48, 380)

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                kind: "music"
                size: win.compact ? 28 : 44
                color: Theme.textTertiary
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                font.family: Theme.font
                font.pixelSize: win.compact ? 16 : 22
                font.weight: Font.DemiBold
                color: Theme.text
                text: "Сейчас ничего не играет"
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: !win.compact
                font.family: Theme.font
                font.pixelSize: 14
                lineHeight: 1.3
                color: Theme.textSecondary
                text: "Включи трек в Spotify, Яндекс Музыке или в браузере, и Afterglow подхватит его сам."
            }
        }

        // ---- Compact layout: mini player row

        Item {
            anchors.fill: parent
            anchors.margins: 16
            visible: Player.hasPlayer && win.compact

            CoverArt {
                id: miniCover
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(parent.height, 120)
                height: width
                radius: 12
            }

            Column {
                anchors.left: miniCover.right
                anchors.leftMargin: 16
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: Theme.text
                    text: Player.title || "Без названия"
                }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.textSecondary
                    text: Player.artist
                }
                Item { width: 1; height: 4 }
                ThinSlider {
                    width: parent.width
                    value: Player.progress
                    interactive: Player.canSeek
                    onMoved: v => Player.seekTo(v)
                }
                Controls {
                    size: 32
                    visible: parent.width > 150
                }
            }
        }

        // ---- Two views sharing the clock, library and transport:
        //   "lyrics": words on the centre stage, clock + library tilted on the left
        //   "covers": clock on top, cover carousel, lyrics column on the right

        Item {
            id: full
            anchors.fill: parent
            visible: !win.compact

            readonly property bool lyricsView: Config.view !== "covers"
            readonly property int m: 20
            readonly property bool narrow: width < 900
            readonly property real libW: 320
            readonly property bool libDocked: Config.showLibrary && !narrow
            readonly property real lyrW: Math.min(400, width * 0.26)
            readonly property bool lyrShown: !lyricsView && Config.showLyrics && Player.hasPlayer
                && (Lyrics.status === "ready" || Lyrics.status === "loading")
                && width >= (libDocked ? 1240 : 900)
            readonly property real cx0: libDocked ? m + libW + (lyricsView ? 40 : 16) : m
            readonly property real cx1: lyrShown ? width - m - lyrW - 16 : width - m
            readonly property real panelBottom: search.y - 16
            property real tilt: lyricsView ? 16 : 0
            Behavior on tilt { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

            component Ease: NumberAnimation { duration: 520; easing.type: Easing.OutCubic }

            // Lyrics view geometry, in proportions of the window: list block at ~16% from
            // the left, stage centred, compact search + transport centred at the bottom.
            readonly property real dockW: Math.max(250, Math.min(320, width * 0.17))
            readonly property real dockX: Math.max(m, Math.min(width * 0.16, bar.x - 24 - dockW))
            readonly property real stageW: Math.max(420, Math.min(760, width * 0.38))

            // Pointer activity: moving the mouse brings up the cover cards in the
            // centre; after 5 s of stillness the lyrics take the stage back.
            property bool pointerActive: false
            property point lastPointer: Qt.point(-1, -1)
            // Not while a menu or the builder is open: moving over a menu must not
            // flip the centre underneath it.
            readonly property bool anyMenu: builder.open || menu.open || styleMenu.open || glowMenu.open || settingsMenu.open
            readonly property bool showCards: lyricsView && !anyMenu
                && (Config.centerMode === "cards" || (Config.centerMode === "auto" && pointerActive))

            Timer {
                interval: 150
                repeat: true
                running: windowHover.hovered && full.lyricsView
                onTriggered: {
                    const p = windowHover.point.position;
                    if (p.x === full.lastPointer.x && p.y === full.lastPointer.y) return;
                    const first = full.lastPointer.x < 0;
                    full.lastPointer = p;
                    if (first) return;
                    // Cards come after a little continuous movement, so a nudge does not flip the centre.
                    if (!full.pointerActive && !showDelay.running) showDelay.restart();
                    idle.restart();
                }
            }
            Timer {
                id: showDelay
                interval: Math.max(0, Config.cardsShowDelay) * 1000
                onTriggered: if (idle.running) full.pointerActive = true
            }
            Timer {
                id: idle
                interval: Math.max(1, Config.cardsHideDelay) * 1000
                onTriggered: { full.pointerActive = false; showDelay.stop(); }
            }

            Clock {
                id: clock
                tall: full.lyricsView
                size: full.lyricsView ? Math.max(60, Math.min(170, full.height * 0.15))
                                      : Math.max(56, Math.min(170, full.height * 0.15))
                x: full.lyricsView ? (full.libDocked ? full.dockX : full.m) + (full.dockW - width) / 2
                    : full.cx0 + (full.cx1 - full.cx0 - width) / 2
                y: full.lyricsView ? full.height * 0.03 : full.m
                Behavior on y { Ease {} }
                Behavior on x { Ease {} }
                Behavior on size { Ease {} }
                transform: Rotation {
                    origin.x: 0
                    origin.y: clock.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: full.libDocked ? full.tilt : 0
                    distanceToPlane: 1200
                }
            }

            // ---- covers view

            Item {
                id: coversView
                anchors.fill: parent
                opacity: full.lyricsView ? 0 : 1
                scale: full.lyricsView ? 0.94 : 1
                visible: opacity > 0.01
                Behavior on opacity { Ease {} }
                Behavior on scale { Ease {} }

                // Loaded only while the covers view is on screen (frees its textures otherwise).
                Loader {
                    id: flow
                    active: coversView.visible
                    x: full.cx0
                    width: full.cx1 - full.cx0
                    y: clock.y + clock.height + 8
                    height: (lyricLine.visible ? lyricLine.y : search.y) - y - 12
                    Behavior on x { Ease {} }
                    Behavior on width { Ease {} }
                    sourceComponent: CoverFlow {}
                }

                // Lyrics enabled but no room for the column: the current line under the covers.
                Item {
                    id: lyricLine
                    x: full.cx0
                    width: full.cx1 - full.cx0
                    height: 44
                    y: search.y - height - 10
                    visible: Config.showLyrics && !full.lyrShown && Lyrics.synced && Lyrics.status === "ready"
                    KaraokeLine {
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, parent.width - 32)
                        text: Lyrics.current || "♪"
                        active: true
                        progress: Lyrics.lineProgress
                        fontSize: 20
                    }
                }

                Loader {
                    active: coversView.visible
                    x: full.width - full.m - full.lyrW
                    y: full.m
                    width: full.lyrW
                    height: full.panelBottom - full.m
                    opacity: full.lyrShown ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: 320 } }
                    sourceComponent: LyricsView {
                        fontSize: Math.max(20, Math.min(28, width / 14))
                    }
                }
            }

            // ---- lyrics view

            // Unloaded in the covers view (its letters and layers cost memory).
            Loader {
                id: stageView
                active: full.lyricsView || opacity > 0.01
                width: full.stageW
                x: (full.width - width) / 2
                y: full.height * 0.24
                height: search.y - y - 24
                sourceComponent: KineticLyrics {
                    maxFont: Math.max(20, Math.min(54, full.height * 0.05)) * Math.max(0.5, Math.min(1.8, Config.lyricsScale))
                }
                opacity: full.lyricsView && !full.showCards ? 1 : 0
                scale: full.lyricsView && !full.showCards ? 1 : 1.06
                visible: opacity > 0.01
                Behavior on opacity { Ease {} }
                Behavior on scale { Ease {} }
                Behavior on x { Ease {} }
                Behavior on width { Ease {} }
            }

            // Cover cards in place of the lyrics while the pointer moves.
            // Created when they appear, destroyed once faded out.
            Loader {
                id: cards
                active: full.showCards || opacity > 0.01
                sourceComponent: CoverFlow {}
                width: Math.min(full.width - 2 * full.m, full.stageW * 1.15)
                x: (full.width - width) / 2
                height: Math.min(stageView.height, full.height * 0.26)
                y: stageView.y + (stageView.height - height) / 2
                opacity: full.showCards ? 1 : 0
                scale: full.showCards ? 1 : 0.92
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            }

            // Click-away layer for the narrow drawer and the source menu.
            MouseArea {
                anchors.fill: parent
                z: 40
                visible: menu.open || styleMenu.open || glowMenu.open || settingsMenu.open || (full.narrow && Config.showLibrary)
                onWheel: e => e.accepted = true
                onClicked: {
                    if (menu.open || styleMenu.open || glowMenu.open || settingsMenu.open) { menu.open = false; styleMenu.open = false; glowMenu.open = false; settingsMenu.open = false; }
                    else Config.showLibrary = false;
                }
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: full.narrow && Config.showLibrary ? 0.35 : 0
                    Behavior on opacity { NumberAnimation { duration: 260 } }
                }
            }

            LibraryPanel {
                id: library
                onBuilderRequested: builder.show("")
                z: 45
                floating: full.lyricsView && full.libDocked
                // The panel slides over the foot of the digits.
                y: full.lyricsView && full.libDocked ? clock.y + clock.height * 0.84 : full.m
                width: full.lyricsView && full.libDocked ? full.dockW : full.libW
                height: (full.lyricsView && full.libDocked ? bar.y + bar.height : full.panelBottom) - y
                x: !Config.showLibrary ? -width - 40 : full.lyricsView && full.libDocked ? full.dockX : full.m
                Behavior on width { Ease {} }
                opacity: Config.showLibrary ? 1 : 0
                color: full.narrow ? Qt.rgba(Player.tint.r * 0.7, Player.tint.g * 0.7, Player.tint.b * 0.7, 0.95)
                    : floating ? "transparent" : Qt.rgba(1, 1, 1, 0.07)
                Behavior on x { Ease {} }
                Behavior on y { Ease {} }
                Behavior on opacity { NumberAnimation { duration: 300 } }
                transform: Rotation {
                    origin.x: 0
                    origin.y: library.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: full.libDocked ? full.tilt : 0
                    distanceToPlane: 1200
                }
            }

            // Spotify confirmations ("В очереди: …")
            Glass {
                z: 47
                anchors.horizontalCenter: search.horizontalCenter
                y: search.y - height - 10
                width: noticeText.implicitWidth + 32
                height: 36
                radius: 18
                color: Qt.rgba(Player.tint.r * 0.6, Player.tint.g * 0.6, Player.tint.b * 0.6, 0.92)
                opacity: Spotify.notice !== "" && !search.open ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 200 } }
                Text {
                    id: noticeText
                    anchors.centerIn: parent
                    text: Spotify.notice
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
            }

            SearchBar {
                id: search
                onActivated: builder.show("")
                z: 47
                width: full.lyricsView ? bar.width - centreSwitch.width - 10 : Math.min(560, bar.width - 40)
                x: full.lyricsView ? bar.x : bar.x + (bar.width - width) / 2
                Behavior on width { Ease {} }
                y: bar.y - height - 12
                height: 44
            }

            // What the centre shows: lyrics, cards, or cards only while the mouse moves.
            Segments {
                id: centreSwitch
                z: 47
                visible: full.lyricsView
                width: 216
                height: 44
                x: bar.x + bar.width - width
                y: search.y
                color: Qt.rgba(0, 0, 0, 0.28 * Config.menuOpacity)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.12)
                options: [["lyrics", "Текст"], ["auto", "Авто"], ["cards", "Карточки"]]
                value: Config.centerMode
                onPicked: v => Config.centerMode = v
            }

            TransportBar {
                id: bar
                z: 46
                compact: full.lyricsView
                width: full.lyricsView ? Math.max(560, Math.min(800, full.width * 0.42)) : full.width - full.m * 2
                x: full.lyricsView ? (full.width - width) / 2 : full.m
                y: full.height - height - (full.lyricsView ? Math.max(full.m, full.height * 0.11) : full.m)
                Behavior on y { Ease {} }
                onSourceClicked: menu.open = !menu.open
                onStyleClicked: styleMenu.open = !styleMenu.open
                onGlowClicked: { glowMenu.open = !glowMenu.open; settingsMenu.open = false; styleMenu.open = false; }
                onSettingsClicked: { settingsMenu.open = !settingsMenu.open; glowMenu.open = false; styleMenu.open = false; }
                Behavior on x { Ease {} }
                Behavior on width { Ease {} }
            }

            ClipChip {
                z: 48
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: full.m
                hovered: windowHover.hovered
            }

            QueueBuilder {
                id: builder
                z: 70
                anchors.fill: parent
                sheetBottom: bar.y - 12
            }

            // Settings and glow menus open at the right edge of the window, just
            // above the transport bar so they never cover its buttons.
            SettingsMenu {
                id: settingsMenu
                z: 50
                maxHeight: bar.y - 10 - full.m
                x: full.width - width - full.m
                y: Math.max(full.m, bar.y - height - 10)
            }

            GlowMenu {
                id: glowMenu
                z: 50
                x: full.width - width - full.m
                y: Math.max(full.m, bar.y - height - 10)
            }

            StyleMenu {
                id: styleMenu
                z: 50
                x: Math.min(full.width - width - full.m, bar.x + bar.width - width)
                y: bar.y - height - 10
                onPicked: open = false
            }

            SourceMenu {
                id: menu
                z: 50
                x: bar.x + 10
                y: bar.y - height - 10
                onPicked: open = false
            }
        }
    }
}
