import QtQuick

// Hairline slider: thickens and shows a knob on hover; drag or click to set.
Item {
    id: root

    property real value: 0          // 0..1
    property bool interactive: true
    property bool live: false       // also report while dragging (settings), not just on release
    signal moved(real value)

    readonly property bool active: mouse.containsMouse || mouse.pressed
    readonly property real shown: mouse.pressed ? dragValue : value
    property real dragValue: 0

    implicitHeight: 16
    activeFocusOnTab: interactive
    Keys.onLeftPressed: moved(Math.max(0, value - 0.02))
    Keys.onRightPressed: moved(Math.min(1, value + 0.02))

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.active || root.activeFocus ? 6 : 4
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.16)
        Behavior on height { NumberAnimation { duration: Theme.quick } }

        Rectangle {
            width: Math.max(parent.height, parent.width * root.shown)
            height: parent.height
            radius: parent.radius
            color: Player.accent
            Behavior on color { ColorAnimation { duration: Theme.slow } }
        }
    }

    Rectangle {
        width: 14
        height: 14
        radius: 7
        color: "white"
        x: root.width * root.shown - width / 2
        anchors.verticalCenter: parent.verticalCenter
        scale: root.active || root.activeFocus ? 1 : 0
        visible: root.interactive
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutBack } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        function at(x) { return Math.max(0, Math.min(1, x / root.width)); }
        onPressed: e => root.dragValue = at(e.x)
        onPositionChanged: e => {
            if (!pressed) return;
            root.dragValue = at(e.x);
            if (root.live) root.moved(root.dragValue);
        }
        onReleased: e => root.moved(at(e.x))
    }
}
