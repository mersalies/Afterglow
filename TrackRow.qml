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

    height: active ? 84 : 56
    z: active ? 2 : 0
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    // How far the card stands out: 0 flat, 1 raised.
    property real lift: active ? 1 : 0
    Behavior on lift { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    // Flat rows sit inside the list; the raised slab reaches past them on both sides.
    readonly property real inset: 14
    readonly property real depth: 11 * lift     // thickness of the slab
    readonly property color glow: Qt.lighter(Player.accent, 1.25)

    // The beat reaches the raised slab: it comes forward with the bass and its
    // edge lights up on a kick.
    property real bass: active && Player.isPlaying ? Audio.bass : 0
    Behavior on bass { NumberAnimation { duration: 110 } }
    property real kick: 0
    NumberAnimation on kick { id: kickFade; to: 0; duration: 480; easing.type: Easing.OutCubic; running: false }
    Connections {
        target: Audio
        enabled: root.active && Player.isPlaying
        function onKicked(strength) { root.kick = Math.min(1, 0.4 + strength * 0.6); kickFade.restart(); }
    }

    // The slab: the top face over a stack of edges, each a step lower and darker,
    // standing on a short, tight shadow. All of it swells from the middle.
    Item {
        id: slab
        visible: root.lift > 0.01
        x: card.x
        y: card.y
        width: card.width
        height: card.height
        scale: 1 + (0.012 + root.bass * 0.022 + root.kick * 0.012) * root.lift
        z: -1

        RectangularShadow {
            anchors.fill: parent
            offset.y: root.depth + 5
            radius: card.radius
            blur: 12
            spread: 0
            color: Qt.rgba(0, 0, 0, 0.6 * root.lift)
        }
        // A halo in the cover's colour, breathing with the bass.
        RectangularShadow {
            anchors.fill: parent
            radius: card.radius
            blur: 18 + root.bass * 22
            spread: 1 + root.kick * 4
            color: Qt.rgba(root.glow.r, root.glow.g, root.glow.b, (0.18 + root.bass * 0.5 + root.kick * 0.25) * root.lift)
        }
        Repeater {
            model: 5
            Rectangle {
                required property int index
                readonly property real k: (5 - index) / 5        // 1 at the bottom, towards 0 under the face
                y: root.depth * k
                width: parent.width
                height: parent.height
                radius: card.radius
                color: Qt.rgba(Player.tint.r * (1.1 + 1.2 * (1 - k)) + 0.05, Player.tint.g * (1.1 + 1.2 * (1 - k)) + 0.05,
                               Player.tint.b * (1.1 + 1.2 * (1 - k)) + 0.05, 0.98 * root.lift)
                border.width: index === 0 ? 1 : 0
                border.color: Qt.rgba(1, 1, 1, 0.14 * root.lift)
            }
        }
    }

    Rectangle {
        id: card
        // Raised, it keeps a little room at the sides to swell into.
        x: root.inset * (1 - root.lift) + 5 * root.lift
        y: 4 * root.lift
        width: parent.width - x * 2
        height: parent.height - (4 + 16) * root.lift
        scale: slab.scale
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
            border.width: 1 + root.kick
            border.color: Qt.tint(Qt.rgba(1, 1, 1, 0.26), Qt.rgba(root.glow.r, root.glow.g, root.glow.b, Math.min(1, root.bass + root.kick)))
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
