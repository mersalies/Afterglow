import QtQuick

// Put inside a block to let it be dragged around while "move blocks" is on in
// the settings (Config.editLayout). The block itself applies the offset:
//   transform: Translate { x: Config.posDeckX * span.width; y: Config.posDeckY * span.height }
// Offsets are kept as shares of the window, so they survive resizing.
// Double-click puts the block back.
Item {
    id: root

    property string key            // Config key without the X / Y ending
    property string label
    property Item span             // what the offsets are a share of (it must not move)

    anchors.fill: parent
    z: 1000
    visible: Config.editLayout

    Rectangle {
        anchors.fill: parent
        anchors.margins: -6
        radius: 14
        color: Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, grab.pressed ? 0.22 : grab.containsMouse ? 0.14 : 0.07)
        border.width: 1.5
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
            from = mapToItem(root.span, e.x, e.y);
            fx = Config[root.key + "X"];
            fy = Config[root.key + "Y"];
        }
        onPositionChanged: e => {
            if (!pressed) return;
            const p = mapToItem(root.span, e.x, e.y);
            Config[root.key + "X"] = Math.max(-1, Math.min(1, fx + (p.x - from.x) / Math.max(1, root.span.width)));
            Config[root.key + "Y"] = Math.max(-1, Math.min(1, fy + (p.y - from.y) / Math.max(1, root.span.height)));
        }
        onDoubleClicked: { Config[root.key + "X"] = 0; Config[root.key + "Y"] = 0; }
        onWheel: e => e.accepted = true
    }
}
