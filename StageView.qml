import QtQuick
import QtQuick.Shapes

// The "stage" view: nothing but the backdrop, and on it three blocks: the covers
// (a shelf or a disc; or one cover with the line being sung), the
// progress line with the tools, and the track's name over one row of borderless
// controls. No bars, no panels. With "move blocks" on in the settings each
// block can be dragged where you like.
Item {
    id: root

    signal sourceClicked
    signal styleClicked
    signal glowClicked
    signal settingsClicked
    signal searchClicked
    signal modeClicked
    signal lyricsModeClicked

    // Where the search sheet grows from, and where the menus open (our coordinates).
    readonly property rect searchSpot: Qt.rect(seekBox.x + Config.posSeekX * width + tools.x + searchBtn.x,
                                               seekBox.y + Config.posSeekY * height + tools.y, searchBtn.width, searchBtn.height)
    readonly property real rowX: ctrlBox.x + Config.posControlsX * width
    readonly property real rowY: ctrlBox.y + Config.posControlsY * height + row.y
    readonly property real rowW: row.width
    readonly property real cardSize: flow.item?.cardSize ?? flow.item?.d ?? 280

    readonly property real colW: Math.max(420, Math.min(width * 0.54, 900))
    readonly property color glow: Qt.lighter(Player.accent, 1.2)

    readonly property string style: Config.stageStyle === "dial" ? "dial" : "arc"
    readonly property bool solo: Config.stageFocus

    // Wheel anywhere below the covers: volume.
    WheelHandler {
        enabled: Player.volumeSupported && !Config.editLayout
        onWheel: e => { if (e.y > seekBox.y) Player.setVolume(Player.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05)); }
    }

    // ---- Block 1: the covers. A shelf ("arc") or a disc
    // ("dial"); or one cover with the line being sung beside it (focus).
    Item {
        id: deckBox
        width: Math.min(root.width - 40, root.colW * 1.25)
        x: (root.width - width) / 2
        y: root.height * 0.30
        height: Math.max(120, seekBox.y - y - 8)
        transform: Translate { x: Config.posDeckX * root.width; y: Config.posDeckY * root.height }

        Loader {
            id: flow
            anchors.fill: parent
            active: root.visible
            sourceComponent: root.solo ? focusComp : root.style === "dial" ? dialComp : flowComp
        }
        Component { id: flowComp; CoverFlow { bare: true } }
        Component { id: dialComp; DialDeck {} }
        Component {
            id: focusComp
            Item {
                id: fd
                readonly property real s: Math.max(120, Math.min(height * 0.84, width * 0.3))
                // The cover on its plate, leaning a little towards the words.
                Rectangle {
                    id: plate
                    x: fd.width / 2 - width - 18
                    y: (fd.height - height) / 2
                    width: fd.s
                    height: fd.s + 46
                    radius: 14
                    color: Qt.rgba(Player.tint.r * 0.6 + 0.05, Player.tint.g * 0.6 + 0.05, Player.tint.b * 0.6 + 0.05, 0.9)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)
                    transform: Rotation {
                        origin.x: plate.width / 2
                        origin.y: plate.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: 14
                        distanceToPlane: 1400
                    }
                    CrossfadeImage {
                        x: 6
                        y: 6
                        width: parent.width - 12
                        height: width
                        source: Player.localArt || Player.artUrl
                        sourceSize: 512
                    }
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 7
                        width: parent.width
                        Text {
                            width: parent.width - 20
                            x: 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: Player.title
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            width: parent.width - 20
                            x: 10
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: Player.artist
                            font.family: Theme.font
                            font.pixelSize: 11
                            color: Theme.textSecondary
                        }
                    }
                    TapHandler { onTapped: Player.toggle() }
                }
                KaraokeLine {
                    x: fd.width / 2 + 14
                    width: fd.width / 2 - 28
                    anchors.verticalCenter: parent.verticalCenter
                    wrap: true
                    text: Lyrics.status === "ready" && Lyrics.synced ? (Lyrics.current || "♪")
                        : Lyrics.status === "loading" ? "…" : "♪"
                    active: true
                    progress: Lyrics.lineProgress
                    fontSize: Math.max(22, Math.min(46, fd.s * 0.16))
                }
            }
        }

        Movable { key: "posDeck"; label: "Обложки"; span: root }
    }

    // ---- Block 2: the progress line (the disc has its own ring), and under it
    // where we are among the covers (left) and the tools (right).
    Item {
        id: seekBox
        width: root.colW
        x: (root.width - width) / 2
        y: root.height * 0.685
        height: curve.height + 6 + tools.height
        transform: Translate { x: Config.posSeekX * root.width; y: Config.posSeekY * root.height }

        Item {
            id: curve
            width: parent.width
            height: 64
            visible: root.style !== "dial" || root.solo

            // The line sags deep, like the edge of the floor under the covers.
            readonly property real sag: 40
            readonly property real pad: 44          // room for the times at both ends
            readonly property real x0: pad
            readonly property real x1: width - pad
            readonly property real shown: seek.pressed ? seek.at : Player.progress
            // Point on the curve at t (0..1): quadratic through the ends, lowest in the middle.
            function px(t) { return x0 + (x1 - x0) * t; }
            function py(t) { return 8 + sag * 4 * t * (1 - t); }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.3)
                    strokeWidth: 1.5
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: curve.x0; startY: curve.py(0)
                    PathQuad { x: curve.x1; y: curve.py(1); controlX: curve.width / 2; controlY: 8 + curve.sag * 2 }
                }
                // The played part: the same curve cut at the playhead (de Casteljau).
                ShapePath {
                    strokeColor: root.glow
                    strokeWidth: 2.2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: curve.x0; startY: curve.py(0)
                    PathQuad {
                        x: curve.px(curve.shown); y: curve.py(curve.shown)
                        controlX: curve.x0 + (curve.width / 2 - curve.x0) * curve.shown
                        controlY: curve.py(0) + curve.sag * 2 * curve.shown
                    }
                }
            }

            Rectangle {
                width: seek.containsMouse || seek.pressed ? 12 : 8
                height: width
                radius: width / 2
                x: curve.px(curve.shown) - width / 2
                y: curve.py(curve.shown) - height / 2
                color: root.glow
                Behavior on width { NumberAnimation { duration: Theme.quick } }
            }

            Text {
                anchors.right: parent.left
                anchors.rightMargin: -curve.pad + 10
                y: curve.py(0) - height / 2
                text: Player.fmt(seek.pressed ? seek.at * Player.length : Player.position)
                font.family: Theme.font
                font.pixelSize: 12
                font.features: { "tnum": 1 }
                color: Theme.textSecondary
            }
            Text {
                anchors.left: parent.right
                anchors.leftMargin: -curve.pad + 10
                y: curve.py(1) - height / 2
                text: Player.length > 0 ? Player.fmt(Player.length) : "–:––"
                font.family: Theme.font
                font.pixelSize: 12
                font.features: { "tnum": 1 }
                color: Theme.textSecondary
            }

            MouseArea {
                id: seek
                x: curve.x0
                width: curve.x1 - curve.x0
                height: parent.height
                hoverEnabled: true
                enabled: Player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                property real at: 0
                function set(mx) { at = Math.max(0, Math.min(1, mx / width)); }
                onPressed: e => set(e.x)
                onPositionChanged: e => { if (pressed) set(e.x); }
                onReleased: Player.seekTo(at)
            }
        }

        Row {
            id: dots
            x: 4
            y: tools.y + (tools.height - height) / 2
            spacing: 7
            readonly property var deck: flow.item?.go ? flow.item : null
            Repeater {
                model: Math.min(dots.deck?.items.length ?? 0, 12)
                Rectangle {
                    required property int index
                    readonly property bool on: index === Math.round(dots.deck?.pos ?? 0)
                    anchors.verticalCenter: parent.verticalCenter
                    width: on ? 8 : 5
                    height: width
                    radius: width / 2
                    color: on ? "white" : Qt.rgba(1, 1, 1, 0.4)
                    Behavior on width { NumberAnimation { duration: Theme.quick } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dots.deck.go(index - dots.deck.target)
                    }
                }
            }
        }

        Row {
            id: tools
            x: parent.width - width - 4
            y: curve.height + 6
            spacing: 10
            Round { id: searchBtn; icon: "search"; tooltip: "Поиск (Q)"; onClicked: root.searchClicked() }
            Round { icon: "covers"; tooltip: root.style === "dial" ? "Обложки дугой" : "Обложка диском"; onClicked: Config.cycleStageStyle() }
            Round { icon: "music"; toggled: Config.stageFocus; tooltip: "Одна обложка и строка текста"; onClicked: Config.stageFocus = !Config.stageFocus }
            Round { icon: "lyrics"; tooltip: "Режим «Текст»: слова песни по центру (V)"; onClicked: root.lyricsModeClicked() }
            Round { icon: "gear"; tooltip: "Настройки"; onClicked: root.settingsClicked() }
        }

        Movable { key: "posSeek"; label: "Перемотка и кнопки"; span: root }
    }

    component Round: IconButton {
        size: 34
        iconSize: 16
        Rectangle {
            z: -1
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(0, 0, 0, 0.32)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
        }
    }

    // ---- Block 3: the track's name and the controls
    Item {
        id: ctrlBox
        width: root.colW
        x: (root.width - width) / 2
        y: seekBox.y + seekBox.height + Math.max(8, root.height * 0.018)
        height: row.y + row.height
        transform: Translate { x: Config.posControlsX * root.width; y: Config.posControlsY * root.height }

        // ---- The track
        Column {
            id: names
            width: parent.width
            spacing: 3

            KaraokeLine {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, parent.width)
                visible: Config.showLyrics && !root.solo && Lyrics.synced && Lyrics.status === "ready" && root.height > 620
                text: Lyrics.current || "♪"
                active: true
                progress: Lyrics.lineProgress
                fontSize: 17
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Player.title || "Ничего не играет"
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.Bold
                color: Theme.text
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Player.local && LocalPlayer.loading ? "Загружаю трек…"
                    : [Player.artist, Player.album].filter(s => s).join(" — ")
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textSecondary
            }
        }

        // ---- Controls: service and panels on the left, transport in the middle,
        // lyrics, look and volume on the right.
        Item {
            id: row
            width: parent.width
            y: Math.min(root.height - ctrlBox.y - height - 14, names.y + names.height + Math.max(10, root.height * 0.02))
            height: 52

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // The service: its badge; a click opens the service menu.
                Item {
                    id: sourceBtn
                    readonly property bool picked: Config.source !== "auto"
                    readonly property string key: picked ? Config.source : Player.hasPlayer ? Player.source : (Config.defaultPlayer || "")
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    height: 34
                    PlatformBadge {
                        anchors.centerIn: parent
                        platform: Player.local && !sourceBtn.picked ? "afterglow" : sourceBtn.key
                        size: 24
                        scale: srcMouse.containsMouse ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.quick } }
                    }
                    MouseArea {
                        id: srcMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sourceClicked()
                    }
                }
                IconButton { icon: "library"; size: 34; iconSize: 17; toggled: Config.showLibrary; tooltip: "Библиотека (B)"; onClicked: Config.showLibrary = !Config.showLibrary }
                IconButton { icon: "heart"; size: 34; iconSize: 17; toggled: Likes.current; tooltip: Likes.hint; enabled: Player.title !== ""; onClicked: Likes.toggle() }
            }

            Row {
                anchors.centerIn: parent
                spacing: 14
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "prev"; size: 38; iconSize: 22
                    tooltip: "Предыдущий трек"
                    enabled: Player.canPrevious
                    onClicked: Player.previous()
                }
                // Play: a disc in the cover's colour.
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46
                    height: 46
                    opacity: Player.canToggle || !Player.hasPlayer ? 1 : 0.4
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: root.glow
                        scale: playMouse.pressed ? 0.92 : playMouse.containsMouse ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.quick } }
                        Behavior on color { ColorAnimation { duration: Theme.slow } }
                    }
                    Icon {
                        anchors.centerIn: parent
                        kind: Player.isPlaying ? "pause" : "play"
                        size: 22
                        color: "white"
                    }
                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Player.toggle()
                    }
                }
                IconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "next"; size: 38; iconSize: 22
                    tooltip: "Следующий трек"
                    enabled: Player.canNext
                    onClicked: Player.next()
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                IconButton { icon: "lyrics"; size: 34; iconSize: 17; toggled: Config.showLyrics; tooltip: "Строка текста (L)"; onClicked: Config.showLyrics = !Config.showLyrics }
                IconButton { icon: "film"; size: 34; iconSize: 17; toggled: Config.videoBackground; tooltip: "Клип на фоне (C)"; onClicked: Config.videoBackground = !Config.videoBackground }
                IconButton { icon: "glow"; size: 34; iconSize: 17; toggled: Config.glowEnabled; tooltip: "Подсветка экрана"; onClicked: root.glowClicked() }
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: volHover.hovered ? 34 + 78 : 34
                    height: 34
                    clip: true
                    visible: Player.volumeSupported
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    HoverHandler { id: volHover }
                    Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; kind: "volume"; size: 18; color: Theme.textSecondary }
                    ThinSlider {
                        x: 36
                        width: 70
                        anchors.verticalCenter: parent.verticalCenter
                        value: Player.volume
                        live: true
                        onMoved: v => Player.setVolume(v)
                    }
                }
            }
        }

        Movable { key: "posControls"; label: "Трек и управление"; span: root }
    }
}
