import QtQuick
import Quickshell.Widgets

// Bottom glass bar. Full: source picker, transport, progress with times, volume,
// view toggles. Compact (lyrics view): source dot, transport, a mini now-playing
// with a hairline progress, toggles.
Glass {
    id: root

    property bool compact: false
    signal sourceClicked
    signal styleClicked
    signal glowClicked
    signal settingsClicked
    readonly property alias styleButton: styleBtn
    readonly property alias sourceButton: sourceBtn
    readonly property bool roomy: !compact && width > 900

    radius: height / 2
    height: compact ? 52 : 64

    // Wheel over the bar: volume.
    WheelHandler {
        enabled: Player.volumeSupported
        onWheel: e => Player.setVolume(Player.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))
    }
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

    // Source pill: the service's badge on a tint of its colour, with a ring that
    // breathes while it plays, so where the music comes from reads at a glance.
    Rectangle {
        id: sourceBtn
        readonly property string key: Player.hasPlayer ? Player.source
            : (Config.defaultPlayer || "")
        readonly property color tone: Player.hasPlayer || Config.defaultPlayer ? Player.sourceColor(key) : Theme.textTertiary
        x: root.compact ? 6 : 10
        anchors.verticalCenter: parent.verticalCenter
        height: root.compact ? 40 : 44
        width: root.compact ? 64 : sourceRow.implicitWidth + 26
        radius: height / 2
        color: Qt.rgba(tone.r, tone.g, tone.b, srcMouse.containsMouse ? 0.34 : 0.2)
        border.width: 1
        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.55)
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        Row {
            id: sourceRow
            anchors.centerIn: parent
            spacing: 7
            Item {
                anchors.verticalCenter: parent.verticalCenter
                width: 28
                height: 28
                Rectangle {
                    id: ring
                    anchors.centerIn: parent
                    width: 28
                    height: 28
                    radius: 14
                    color: "transparent"
                    border.width: 2
                    border.color: sourceBtn.tone
                    opacity: 0
                    SequentialAnimation {
                        running: Player.isPlaying
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) { ring.opacity = 0; ring.scale = 1; }
                        ParallelAnimation {
                            NumberAnimation { target: ring; property: "scale"; from: 1; to: 1.55; duration: 1600; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 1600; easing.type: Easing.OutCubic }
                        }
                        PauseAnimation { duration: 600 }
                    }
                }
                PlatformBadge {
                    anchors.centerIn: parent
                    platform: Player.local ? (Player.source || "afterglow") : sourceBtn.key
                    size: 26
                    opacity: Player.hasPlayer ? 1 : 0.6
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.compact
                text: Player.local || Config.source === "auto" ? (Player.hasPlayer ? Player.sourceLabel : "Источник") : Player.sourceName(Config.source, Player.active)
                width: Math.min(implicitWidth, root.roomy ? 150 : 90)
                elide: Text.ElideRight
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                kind: "chevron"
                size: 16
                color: Theme.textSecondary
                rotation: 180
            }
        }

        MouseArea {
            id: srcMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sourceClicked()
        }
    }

    Controls {
        id: controls
        anchors.left: sourceBtn.right
        anchors.leftMargin: root.compact ? 8 : 14
        anchors.verticalCenter: parent.verticalCenter
        size: root.compact ? 30 : 36
    }

    // Full: progress with times
    Item {
        id: progress
        visible: !root.compact
        anchors.left: controls.right
        anchors.leftMargin: 18
        anchors.right: tail.left
        anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        height: 40

        Text {
            id: tPos
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Player.fmt(Player.position)
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
            color: Theme.textTertiary
        }
        ThinSlider {
            anchors.left: tPos.right
            anchors.leftMargin: 10
            anchors.right: tLen.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            value: Player.progress
            interactive: Player.canSeek
            onMoved: v => Player.seekTo(v)
        }
        Text {
            id: tLen
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Player.length > 0 ? Player.fmt(Player.length) : "–:––"
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
            color: Theme.textTertiary
        }
    }

    // Compact: mini now-playing with a hairline progress you can click to seek
    Item {
        id: mini
        visible: root.compact
        anchors.left: controls.right
        anchors.leftMargin: 12
        anchors.right: tail.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 36

        ClippingRectangle {
            id: miniArt
            width: 36
            height: 36
            radius: 7
            color: Qt.rgba(1, 1, 1, 0.1)
            Image {
                anchors.fill: parent
                source: Player.localArt || Player.artUrl
                sourceSize.width: 72
                sourceSize.height: 72
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            anchors.left: miniArt.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Player.title || "Ничего не играет"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: Player.local && LocalPlayer.loading ? "Загружаю трек…"
                    : [Player.artist, Player.album].filter(s => s).join(" — ")
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.textSecondary
            }
            Item { width: 1; height: 3 }
            ThinSlider {
                width: parent.width
                height: 6
                value: Player.progress
                interactive: Player.canSeek
                onMoved: v => Player.seekTo(v)
            }
        }
    }

    Row {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: root.compact ? 8 : 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.compact ? 2 : 4

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: root.roomy && Player.volumeSupported
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                kind: "volume"
                size: 18
                color: Theme.textTertiary
            }
            ThinSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: 90
                value: Player.volume
                onMoved: v => Player.setVolume(v)
            }
            Item { width: 8; height: 1 }
        }

        // Content: how the lyrics move, the library, which view.
        IconButton {
            id: styleBtn
            icon: "style"
            size: root.compact ? 34 : 38
            tooltip: "Анимация текста (S)"
            onClicked: root.styleClicked()
        }
        IconButton {
            icon: "library"
            size: root.compact ? 34 : 38
            toggled: Config.showLibrary
            tooltip: "Библиотека (B)"
            onClicked: Config.showLibrary = !Config.showLibrary
        }
        IconButton {
            icon: Config.view === "covers" ? "lyrics" : "covers"
            size: root.compact ? 34 : 38
            tooltip: Config.view === "covers" ? "Текст по центру (V)" : "Обложки (V)"
            onClicked: Config.view = Config.view === "covers" ? "lyrics" : "covers"
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 1
            height: 22
            color: Theme.hairline
        }

        // Look: edge light and general settings.
        IconButton {
            icon: "glow"
            size: root.compact ? 34 : 38
            toggled: Config.glowEnabled
            tooltip: "Подсветка экрана (G — вкл/выкл)"
            onClicked: root.glowClicked()
        }
        IconButton {
            icon: "gear"
            size: root.compact ? 34 : 38
            tooltip: "Настройки"
            onClicked: root.settingsClicked()
        }
    }
}
