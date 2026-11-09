import QtQuick

// Previous / play-pause / next.
Row {
    id: root

    property real size: 44
    spacing: size * 0.4

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "prev"
        size: root.size
        iconSize: root.size * 0.5
        tooltip: "Предыдущий трек"
        enabled: Player.canPrevious
        onClicked: Player.previous()
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: Player.isPlaying ? "pause" : "play"
        size: root.size * 1.36
        iconSize: root.size * 0.6
        filled: true
        tooltip: Player.isPlaying ? "Пауза" : "Играть"
        enabled: Player.canToggle
        onClicked: Player.toggle()
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "next"
        size: root.size
        iconSize: root.size * 0.5
        tooltip: "Следующий трек"
        enabled: Player.canNext
        onClicked: Player.next()
    }
}
