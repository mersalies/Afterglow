import QtQuick

// Entry to the queue builder above the transport bar: shows what is queued next
// and opens the builder on click (or on Q / "/").
Glass {
    id: root

    signal activated
    readonly property bool open: false   // kept for layout bindings that read it

    radius: height / 2
    implicitHeight: 44
    border.color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.12)

    Icon {
        id: glass
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        kind: "search"
        size: 18
        color: Theme.textTertiary
    }

    Text {
        anchors.left: glass.right
        anchors.leftMargin: 10
        anchors.right: count.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: Queue.items.length > 0
            ? "Далее: " + Queue.items[0].title + (Queue.items[0].artist ? " — " + Queue.items[0].artist : "")
            : "Найти и добавить в очередь: Spotify, YouTube, SoundCloud"
        font.family: Theme.font
        font.pixelSize: 14
        color: Queue.items.length > 0 ? Theme.textSecondary : Theme.textTertiary
    }

    Rectangle {
        id: count
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: Queue.items.length > 0
        width: Math.max(26, countText.implicitWidth + 14)
        height: 26
        radius: 13
        color: Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, 0.35)
        Text {
            id: countText
            anchors.centerIn: parent
            text: Queue.items.length
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: Theme.text
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
