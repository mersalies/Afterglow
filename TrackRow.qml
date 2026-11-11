import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// One row in the library panel: thumbnail, title, subtitle. The playing track's
// row is a slab of dark glass lifted off the list: wider than the rows around
// it, with a visible thickness and a deep shadow, its title in the cover's
// colour and bars that move with the music.
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

    height: active ? 76 : 56
    z: active ? 2 : 0
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // How far the card stands out: 0 flat, 1 raised.
    property real lift: active ? 1 : 0
    Behavior on lift { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    // Flat rows sit inside the list; the raised slab reaches past them on both sides.
    readonly property real inset: 14
    readonly property real depth: 6 * lift      // thickness of the slab
    readonly property color glow: Qt.lighter(Player.accent, 1.25)

    RectangularShadow {
        visible: root.lift > 0.01
        anchors.fill: side
        offset.y: 12 * root.lift
        radius: card.radius
        blur: 30
        spread: 2
        color: Qt.rgba(0, 0, 0, 0.65 * root.lift)
    }

    // The slab's front edge: the same plate, a step lower and lighter.
    Rectangle {
        id: side
        visible: root.lift > 0.01
        x: card.x
        y: card.y + root.depth
        width: card.width
        height: card.height
        radius: card.radius
        color: Qt.rgba(Player.tint.r * 1.9 + 0.1, Player.tint.g * 1.9 + 0.1, Player.tint.b * 1.9 + 0.1, 0.96 * root.lift)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16 * root.lift)
    }

    Rectangle {
        id: card
        x: root.inset * (1 - root.lift)
        y: 3 * root.lift
        width: parent.width - x * 2
        height: parent.height - (3 + 9) * root.lift
        radius: 12 + 2 * root.lift
        color: root.active ? "transparent" : mouse.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.quick } }

        // The top face: dark glass, a touch lighter towards the top edge.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            opacity: root.lift
            visible: opacity > 0.01
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(Player.tint.r * 0.75 + 0.07, Player.tint.g * 0.75 + 0.07, Player.tint.b * 0.75 + 0.07, 0.97) }
                GradientStop { position: 1; color: Qt.rgba(Player.tint.r * 0.4 + 0.02, Player.tint.g * 0.4 + 0.02, Player.tint.b * 0.4 + 0.02, 0.97) }
            }
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.24)
        }
    }

    ClippingRectangle {
        id: thumb
        x: card.x + 8 + 2 * root.lift
        y: card.y + (card.height - height) / 2
        width: 40 + 6 * root.lift
        height: width
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
            sourceSize.width: 96
            sourceSize.height: 96
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        anchors.left: thumb.right
        anchors.leftMargin: 12
        anchors.right: bars.visible ? bars.left : actions.left
        anchors.rightMargin: 10
        y: card.y + (card.height - height) / 2
        spacing: 2

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            font.family: Theme.font
            font.pixelSize: 14 + root.lift
            font.weight: root.active ? Font.Bold : Font.DemiBold
            color: root.active ? root.glow : Theme.text
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

    // Playing: three bars moving with the music (they make room for the hover actions).
    Row {
        id: bars
        anchors.right: parent.right
        anchors.rightMargin: 18
        y: card.y + (card.height - height) / 2
        height: 20
        spacing: 3
        visible: root.active && opacity > 0.01
        opacity: actions.visible && (mouse.containsMouse || hover.hovered) ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        Repeater {
            model: [2, 7, 13]
            Rectangle {
                required property int modelData
                anchors.bottom: parent.bottom
                width: 3
                radius: 1.5
                height: 3 + (bars.height - 3) * (Player.isPlaying ? Math.min(1, (Audio.levels[modelData] ?? 0) * 1.3) : 0.15)
                color: root.glow
                Behavior on height { NumberAnimation { duration: 110 } }
            }
        }
    }

    // Hover actions
    Row {
        id: actions
        anchors.right: parent.right
        anchors.rightMargin: card.x + 6
        y: card.y + (card.height - height) / 2
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
