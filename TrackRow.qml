import QtQuick
import Quickshell.Widgets

// One row in the library panel: thumbnail, title, subtitle.
Item {
    id: root

    property string title
    property string subtitle
    property string art
    property bool active: false
    property bool round: false
    property bool queueable: false   // "+" (add to the end of the queue)
    property bool nextable: false    // "play next"
    property bool editable: false    // up / down / remove, for rows inside the queue
    property bool glassActive: false   // active row as a raised glass card
    signal clicked
    signal queued
    signal queuedNext
    signal movedUp
    signal movedDown
    signal removed

    height: 56

    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: 0
        radius: 12
        color: root.active ? (root.glassActive ? Qt.rgba(1, 1, 1, 0.18 * Config.panelOpacity) : Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, 0.22))
            : mouse.containsMouse ? Theme.hover : "transparent"
        border.width: root.active && root.glassActive ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.28)
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    ClippingRectangle {
        id: thumb
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: root.round ? 20 : 8
        color: Qt.rgba(1, 1, 1, 0.08)

        Icon {
            anchors.centerIn: parent
            kind: "music"
            size: 18
            color: Theme.textTertiary
            visible: img.status !== Image.Ready
        }
        Image {
            id: img
            anchors.fill: parent
            source: root.art
            sourceSize.width: 80
            sourceSize.height: 80
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        anchors.left: thumb.right
        anchors.leftMargin: 12
        anchors.right: actions.visible ? actions.left : parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.subtitle
            visible: text !== ""
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.textSecondary
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    // Hover actions
    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        visible: root.queueable || root.nextable || root.editable
        opacity: mouse.containsMouse || hover.hovered ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        HoverHandler { id: hover }

        IconButton { visible: root.editable; icon: "up"; size: 28; tooltip: "Выше"; onClicked: root.movedUp() }
        IconButton { visible: root.editable; icon: "down"; size: 28; tooltip: "Ниже"; onClicked: root.movedDown() }
        IconButton { visible: root.editable; icon: "close"; size: 28; tooltip: "Убрать"; onClicked: root.removed() }
        IconButton { visible: root.nextable; icon: "playnext"; size: 30; tooltip: "Следующим"; onClicked: root.queuedNext() }
        IconButton { visible: root.queueable; icon: "plus"; size: 30; tooltip: "В конец очереди"; onClicked: root.queued() }
    }
}
