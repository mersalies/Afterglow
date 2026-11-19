import QtQuick

// Put inside a block to let it be arranged while "move blocks" is on
// (Config.editLayout): drag it anywhere; pressing it also picks it, and the picked
// block's lean and size are set with two lines in the corner of the window. The block itself applies what is stored in Config.layout:
//   readonly property var lay: Config.lay("deck")
//   transform: [ Scale {...lay.scale}, Rotation {...lay.tilt}, Translate {...lay.x * span.width} ]
// Offsets are shares of the window, so they survive resizing. Double-click puts
// the block back as it was.
Item {
    id: root

    property string key            // name in Config.layout
    property string label
    property Item span             // what the offsets are a share of (it must not move)
    property bool plain: false     // position only: no lean, no size

    readonly property var lay: Config.lay(key)
    readonly property bool chosen: Config.editKey === key

    anchors.fill: parent
    z: 1000
    visible: Config.editLayout

    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 14
        color: Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, grab.pressed ? 0.22 : grab.containsMouse || root.chosen ? 0.14 : 0.07)
        border.width: root.chosen ? 3 : 1.5
        border.color: Qt.lighter(Player.accent, 1.3)

        Rectangle {
            x: 10
            y: -height / 2
            width: tag.implicitWidth + 16
            height: 22
            radius: 11
            color: Qt.lighter(Player.accent, 1.3)
            Text {
                id: tag
                anchors.centerIn: parent
                text: root.label
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.Bold
                color: "#111"
            }
        }
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point from
        property real fx
        property real fy
        onPressed: e => {
            Config.editKey = root.key;
            from = mapToItem(root.span, e.x, e.y);
            fx = root.lay.x;
            fy = root.lay.y;
        }
        onPositionChanged: e => {
            if (!pressed) return;
            const p = mapToItem(root.span, e.x, e.y);
            Config.setLay(root.key, {
                x: Math.max(-1, Math.min(1, fx + (p.x - from.x) / Math.max(1, root.span.width))),
                y: Math.max(-1, Math.min(1, fy + (p.y - from.y) / Math.max(1, root.span.height)))
            });
        }
        onDoubleClicked: Config.setLay(root.key, null)
        onWheel: e => e.accepted = true
    }

    // Lean and size.
    // One panel for the chosen block, fixed in the bottom right corner of the span,
    // so the block's lean and size do not bend it.
    Rectangle {
        parent: root.span
        z: 2000
        visible: root.visible && root.chosen && !root.plain
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 18
        width: 280
        height: 78
        radius: 14
        color: Theme.menuColor(0.95)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        MouseArea { anchors.fill: parent; onWheel: e => e.accepted = true }

        component Line: Row {
            id: line
            property string name
            property string shown
            property real value
            signal moved(real v)
            x: 12
            width: parent.width - 24
            spacing: 8
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                text: line.name
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: Theme.text
            }
            ThinSlider {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 56 - 40 - 16
                live: true
                value: line.value
                onMoved: v => line.moved(v)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: line.shown
                font.family: Theme.font
                font.pixelSize: 11
                font.features: { "tnum": 1 }
                color: Theme.textSecondary
            }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            spacing: 4
            // Which block the lines belong to: the panel may sit away from it.
            Text {
                x: 12
                text: root.label
                font.family: Theme.font
                font.pixelSize: 11
                font.weight: Font.Bold
                color: Qt.lighter(Player.accent, 1.3)
            }
            // -50°..50°, snapping to straight near the middle.
            Line {
                name: "Наклон"
                shown: Math.round(root.lay.tilt) + "°"
                value: (root.lay.tilt + 50) / 100
                onMoved: v => { const t = v * 100 - 50; Config.setLay(root.key, { tilt: Math.abs(t) < 2 ? 0 : t }); }
            }
            // 0.5×..2×
            Line {
                name: "Размер"
                shown: root.lay.scale.toFixed(2) + "×"
                value: (root.lay.scale - 0.5) / 1.5
                onMoved: v => { const s = 0.5 + v * 1.5; Config.setLay(root.key, { scale: Math.abs(s - 1) < 0.03 ? 1 : s }); }
            }
        }
    }
}
