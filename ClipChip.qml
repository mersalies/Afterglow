import QtQuick

// Small glass chip in the top-right corner: what is on the backdrop, and buttons
// for "another clip" and "no clip / clips on". Fades in while the pointer is over
// the window or a clip is being looked up.
Glass {
    id: root

    property bool hovered: false

    readonly property bool busy: Clip.status === "searching" || Clip.status === "loading"
    readonly property string label: !Config.videoBackground ? "Клипы выключены"
        : Clip.status === "searching" ? "Ищу клип…"
        : Clip.status === "loading" ? "Загружаю клип…"
        : Clip.status === "ready" ? Clip.videoTitle
        : Clip.status === "none" ? "Клипа нет, на фоне обложка"
        : ""

    radius: height / 2
    height: 40
    width: Math.min(420, row.implicitWidth + 20)
    color: Qt.rgba(Player.tint.r * 0.6, Player.tint.g * 0.6, Player.tint.b * 0.6, 0.85)
    opacity: Player.hasPlayer && label !== "" && (hovered || busy) ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 260 } }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        spacing: 6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            kind: "film"
            size: 18
            color: Theme.textSecondary
            RotationAnimation on rotation {
                running: root.busy
                from: 0; to: 360; duration: 1600; loops: Animation.Infinite
                onRunningChanged: if (!running) parent.rotation = 0
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 260)
            elide: Text.ElideRight
            text: root.label
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.text
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.videoBackground
            icon: "refresh"
            size: 30
            tooltip: "Другой клип"
            onClicked: Clip.next()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            visible: Config.videoBackground && Clip.status === "ready"
            icon: "close"
            size: 30
            tooltip: "Без клипа для этого трека"
            onClicked: Clip.hide()
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "film"
            size: 30
            toggled: Config.videoBackground
            tooltip: Config.videoBackground ? "Выключить клипы (C)" : "Включить клипы (C)"
            onClicked: Config.videoBackground = !Config.videoBackground
        }
    }
}
