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
            if (e.key === Qt.Key_Escape) { Config.editLayout = false; menu.open = false; styleMenu.open = false; glowMenu.open = false; settingsMenu.open = false; builder.hide(); }
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
            else if (e.key === Qt.Key_V) Config.cycleView();
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

            // Three looks: "lyrics" (words in the centre), "covers" (carousel between
            // panels), "stage" (bare carousel and controls on the backdrop).
            readonly property bool stage: Config.view === "stage"
            readonly property bool lyricsView: !stage && Config.view !== "covers"
            // Library and clock float without a sheet, the library leaning in.
            readonly property bool floatSide: lyricsView || stage
            // Where the scene view's centre and bottom bars were put while arranging.
            readonly property var centreLay: Config.lay("centre2")
            readonly property var barLay: lyricsView ? Config.lay("bar2") : ({ x: 0, y: 0 })
            readonly property int m: 20
            readonly property bool narrow: width < 900
            readonly property real libW: 320
            readonly property bool libDocked: Config.showLibrary && !narrow
            readonly property real lyrW: Math.min(400, width * 0.26)
            readonly property bool lyrShown: !floatSide && Config.showLyrics && Player.hasPlayer
                && (Lyrics.status === "ready" || Lyrics.status === "loading")
                && width >= (libDocked ? 1240 : 900)
            readonly property real cx0: libDocked ? m + libW + (lyricsView ? 40 : 16) : m
            readonly property real cx1: lyrShown ? width - m - lyrW - 16 : width - m
            readonly property real panelBottom: search.y - 16
            property real tilt: floatSide ? 33 : 0
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

            // ---- Clock. Each scene (lyrics view, covers view, a music video on the
            // backdrop) has its own: shown or not, and where. It sits in its place
            // in the layout until dragged; then it stays where it was dropped (as a
            // share of the free room, so it survives resizes). Double-click: back.
            readonly property string scene: video.showing ? "Clip" : lyricsView ? "Lyrics" : "Covers"
            readonly property bool clockShown: Config["clockShow" + scene]
            readonly property real clockFx: Config["clock" + scene + "X"]
            readonly property real clockFy: Config["clock" + scene + "Y"]
            readonly property bool clockPlaced: clockFx >= 0 && clockFy >= 0
            readonly property real clockAutoX: stage ? (width - clock.width) / 2
                : lyricsView ? (libDocked ? dockX : m) + (dockW - clock.width) / 2
                : cx0 + (cx1 - cx0 - clock.width) / 2
            readonly property real clockAutoY: stage ? height * 0.012 : lyricsView ? height * 0.03 : m
            // The docked library hangs under the clock while the lyrics scene keeps it in place.
            readonly property bool libUnderClock: Config.clockShowLyrics && !(Config.clockLyricsX >= 0 && Config.clockLyricsY >= 0)

            Clock {
                id: clock
                z: Config.clockLayer === "front" ? 48 : 0
                tall: full.floatSide
                accented: full.stage
                size: (full.stage ? Math.max(60, Math.min(210, full.height * 0.16))
                       : full.lyricsView ? Math.max(60, Math.min(170, full.height * 0.15))
                                       : Math.max(56, Math.min(170, full.height * 0.15))) * Math.max(0.4, Math.min(2.5, Config.clockScale))
                x: full.clockPlaced ? full.clockFx * Math.max(0, full.width - width) : full.clockAutoX
                y: full.clockPlaced ? full.clockFy * Math.max(0, full.height - height) : full.clockAutoY
                opacity: full.clockShown ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 400 } }
                Behavior on y { enabled: !clockDrag.dragging; Ease {} }
                Behavior on x { enabled: !clockDrag.dragging; Ease {} }
                Behavior on size { Ease {} }
                transform: Rotation {
                    origin.x: 0
                    origin.y: clock.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: full.libDocked && !full.clockPlaced && !full.stage ? full.tilt : 0
                    distanceToPlane: 1200
                }

                MouseArea {
                    id: clockDrag
                    anchors.fill: parent
                    property point start
                    property point origin
                    property bool dragging: false
                    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    preventStealing: true
                    onPressed: e => {
                        start = mapToItem(full, e.x, e.y);
                        origin = Qt.point(clock.x, clock.y);
                    }
                    onPositionChanged: e => {
                        const p = mapToItem(full, e.x, e.y);
                        const dx = p.x - start.x, dy = p.y - start.y;
                        if (!dragging && Math.hypot(dx, dy) < 4) return;
                        dragging = true;
                        const fx = Math.max(0, Math.min(1, (origin.x + dx) / Math.max(1, full.width - clock.width)));
                        const fy = Math.max(0, Math.min(1, (origin.y + dy) / Math.max(1, full.height - clock.height)));
                        Config["clock" + full.scene + "X"] = fx;
                        Config["clock" + full.scene + "Y"] = fy;
                    }
                    onReleased: dragging = false
                    onCanceled: dragging = false
                    onDoubleClicked: {
                        Config["clock" + full.scene + "X"] = -1;
                        Config["clock" + full.scene + "Y"] = -1;
                    }
                }
            }

            // ---- covers view

            Item {
                id: coversView
                anchors.fill: parent
                opacity: full.floatSide ? 0 : 1
                scale: full.floatSide ? 0.94 : 1
                visible: opacity > 0.01
                Behavior on opacity { Ease {} }
                Behavior on scale { Ease {} }

                // Loaded only while the covers view is on screen (frees its textures otherwise).
                Loader {
                    id: flow
                    active: coversView.visible
                    x: full.cx0
                    width: full.cx1 - full.cx0
                    // Under the clock while it stands in its place in this view.
                    y: Config.clockShowCovers && !(Config.clockCoversX >= 0 && Config.clockCoversY >= 0)
                        ? full.clockAutoY + clock.height + 8 : full.m
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
                transform: [
                    Scale { origin.x: stageView.width / 2; origin.y: stageView.height / 2; xScale: full.centreLay.scale; yScale: full.centreLay.scale },
                    Rotation { origin.x: stageView.width / 2; origin.y: stageView.height / 2; axis.x: 0; axis.y: 1; axis.z: 0; angle: full.centreLay.tilt; distanceToPlane: 1400 },
                    Translate { x: full.centreLay.x * full.width; y: full.centreLay.y * full.height }
                ]
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
                width: Math.min(full.width - 2 * full.m, full.stageW * 1.15 * Math.max(1, Config.cardsScale))
                x: (full.width - width) / 2
                height: Math.min(stageView.height, full.height * 0.26 * Config.cardsScale)
                y: stageView.y + (stageView.height - height) / 2
                opacity: full.showCards ? 1 : 0
                scale: full.showCards ? 1 : 0.92
                transform: [
                    Scale { origin.x: cards.width / 2; origin.y: cards.height / 2; xScale: full.centreLay.scale; yScale: full.centreLay.scale },
                    Rotation { origin.x: cards.width / 2; origin.y: cards.height / 2; axis.x: 0; axis.y: 1; axis.z: 0; angle: full.centreLay.tilt; distanceToPlane: 1400 },
                    Translate { x: full.centreLay.x * full.width; y: full.centreLay.y * full.height }
                ]
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            }

            // Handles for arranging the scene view's centre and its bottom bars.
            Item {
                z: 60
                visible: Config.editLayout && full.lyricsView
                x: stageView.x
                y: stageView.y
                width: stageView.width
                height: stageView.height
                transform: [
                    Scale { origin.x: stageView.width / 2; origin.y: stageView.height / 2; xScale: full.centreLay.scale; yScale: full.centreLay.scale },
                    Rotation { origin.x: stageView.width / 2; origin.y: stageView.height / 2; axis.x: 0; axis.y: 1; axis.z: 0; angle: full.centreLay.tilt; distanceToPlane: 1400 },
                    Translate { x: full.centreLay.x * full.width; y: full.centreLay.y * full.height }
                ]
                Movable { key: "centre2"; label: "Текст и карточки"; span: full }
            }
            Item {
                z: 60
                visible: Config.editLayout && full.lyricsView
                x: bar.x
                y: search.y
                width: bar.width
                height: bar.y + bar.height - search.y
                Movable { key: "bar2"; label: "Поиск и панель"; span: full; plain: true }
            }

            // ---- stage view
            Loader {
                id: stageDeck
                anchors.fill: parent
                active: full.stage || opacity > 0.01
                opacity: full.stage ? 1 : 0
                scale: full.stage ? 1 : 1.04
                visible: opacity > 0.01
                Behavior on opacity { Ease {} }
                Behavior on scale { Ease {} }
                sourceComponent: StageView {
                    onSourceClicked: menu.open = !menu.open
                    onGlowClicked: { glowMenu.open = !glowMenu.open; settingsMenu.open = false; styleMenu.open = false; }
                    onSettingsClicked: { settingsMenu.open = !settingsMenu.open; glowMenu.open = false; styleMenu.open = false; }
                    onSearchClicked: builder.show("")
                    onModeClicked: Config.cycleView()
                    onLyricsModeClicked: Config.view = "lyrics"
                }
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
                floating: full.floatSide && full.libDocked
                // The panel slides over the foot of the digits; on the stage it
                // stands by itself at the left edge.
                y: full.stage && full.libDocked ? full.height * 0.2
                    : full.lyricsView && full.libDocked ? (full.libUnderClock ? full.clockAutoY + clock.height * 0.84 : full.clockAutoY) : full.m
                width: full.floatSide && full.libDocked ? full.dockW : full.libW
                height: (full.stage && full.libDocked ? full.height - full.m : full.lyricsView && full.libDocked ? bar.y + bar.height : full.panelBottom) - y
                // On the stage it stands close to the covers, its far edge over the first of them.
                x: !Config.showLibrary ? -width - 40
                    : full.stage && full.libDocked ? Math.max(full.m + 12, full.width / 2 - (stageDeck.item?.cardSize ?? 280) * 1.55 - width * 0.9 + 60)
                    : full.lyricsView && full.libDocked ? full.dockX : full.m
                Behavior on width { Ease {} }
                opacity: Config.showLibrary ? 1 : 0
                color: full.narrow ? Qt.rgba(Player.tint.r * 0.7, Player.tint.g * 0.7, Player.tint.b * 0.7, 0.95)
                    : floating ? "transparent" : Qt.rgba(1, 1, 1, 0.07)
                Behavior on x { Ease {} }
                Behavior on y { Ease {} }
                Behavior on opacity { NumberAnimation { duration: 300 } }
                transform: [
                    Scale { origin.x: library.width / 2; origin.y: library.height / 2; xScale: library.lay.scale; yScale: library.lay.scale },
                    Rotation {
                        origin.x: 0
                        origin.y: library.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: (full.libDocked ? full.tilt : 0) + library.lay.tilt
                        distanceToPlane: 1200
                    },
                    Translate { x: library.lay.x * full.width; y: library.lay.y * full.height }
                ]
                // Arranged separately in each of the two floating views.
                readonly property string layKey: full.stage ? "list" : "list2"
                readonly property var lay: full.floatSide && full.libDocked ? Config.lay(layKey) : ({ x: 0, y: 0, tilt: 0, scale: 1 })
                Movable { visible: Config.editLayout && full.floatSide && full.libDocked; key: library.layKey; label: "Список"; span: full }
            }
            // Leaving the stage ends the moving.
            Connections {
                target: full
                function onFloatSideChanged() { if (!full.floatSide) Config.editLayout = false; }
            }

            // Top left corner of the two floating views: arrange the blocks, and stop.
            IconButton {
                z: 81
                x: full.m
                y: full.m
                visible: full.floatSide
                opacity: Config.editLayout || windowHover.hovered ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 300 } }
                icon: "move"
                size: 38
                iconSize: 18
                toggled: Config.editLayout
                tooltip: Config.editLayout ? "Закончить: блоки останутся на местах" : "Двигать блоки: место, наклон, размер"
                onClicked: Config.editLayout = !Config.editLayout
                Rectangle {
                    z: -1
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(0, 0, 0, 0.32)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            // "Move blocks" is on: say so, and offer the way out.
            Glass {
                z: 80
                visible: Config.editLayout
                anchors.horizontalCenter: parent.horizontalCenter
                y: full.m
                width: editRow.implicitWidth + 28
                height: 44
                radius: 22
                color: Theme.menuColor(0.95)
                Row {
                    id: editRow
                    anchors.centerIn: parent
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Перетащи блоки, под каждым — наклон и размер. Двойной клик по блоку — как было."
                        font.family: Theme.font
                        font.pixelSize: 13
                        color: Theme.text
                    }
                    Pill { anchors.verticalCenter: parent.verticalCenter; icon: "refresh"; label: "Сбросить"; onClicked: Config.resetLayout() }
                    Pill { anchors.verticalCenter: parent.verticalCenter; icon: "check"; label: "Готово"; onClicked: Config.editLayout = false }
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

            // Where the search bar sits; the search sheet (builder) draws it and
            // grows out of it.
            Item {
                id: search
                readonly property bool open: builder.open
                readonly property rect spot: stageDeck.item?.searchSpot ?? Qt.rect(0, 0, 44, 44)
                width: full.stage ? spot.width : full.lyricsView ? bar.width - centreSwitch.width - 10 : Math.min(560, bar.width - 40)
                x: full.stage ? spot.x : full.lyricsView ? bar.x : bar.x + (bar.width - width) / 2
                Behavior on width { Ease {} }
                y: full.stage ? spot.y : bar.y - height - 12
                height: full.stage ? spot.height : 44
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
                compact: full.floatSide
                // On the stage the bar is gone; it stays where the stage's own row
                // of controls is, so the menus still open from the right place.
                opacity: full.stage ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: 300 } }
                readonly property real stageY: stageDeck.item?.rowY ?? full.height - 70
                width: full.stage ? (stageDeck.item?.rowW ?? 560) : full.lyricsView ? Math.max(560, Math.min(800, full.width * 0.42)) : full.width - full.m * 2
                x: (full.floatSide ? (full.width - width) / 2 : full.m) + full.barLay.x * full.width
                y: (full.stage ? stageY : full.height - height - (full.lyricsView ? Math.max(full.m, full.height * 0.11) : full.m)) + full.barLay.y * full.height
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
                dockX: search.x
                dockY: search.y
                dockW: search.width
                dockH: search.height
                dockHidden: full.stage
            }

            // Settings and glow menus open at the right edge of the window, just
            // above the transport bar so they never cover its buttons.
            SettingsMenu {
                id: settingsMenu
                z: 50
                scene: full.scene
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
                // Above the search sheet: it picks the service the search uses too.
                z: 75
                x: bar.x + 10
                y: bar.y - height - 10
                onPicked: open = false
            }
        }
    }
}
