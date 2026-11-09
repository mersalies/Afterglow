import QtQuick

// Bar spectrum from cava, rising from the bottom edge.
Row {
    id: root

    property real barGap: 4
    spacing: barGap

    Repeater {
        model: Audio.bars
        Rectangle {
            required property int index
            readonly property real level: Audio.levels[index] ?? 0
            anchors.bottom: parent.bottom
            width: (root.width - root.barGap * (Audio.bars - 1)) / Audio.bars
            height: Math.max(2, root.height * level)
            radius: Math.min(width / 2, 3)
            color: Player.accent
            opacity: 0.35 + 0.65 * level
            Behavior on height { NumberAnimation { duration: 90 } }
        }
    }
}
