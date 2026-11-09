import QtQuick

// Round, borderless icon button with hover, press, toggled and focus states.
Item {
    id: root

    property string icon
    property real size: 40
    property real iconSize: size * 0.5
    property bool filled: false
    property bool toggled: false
    property bool enabled: true
    property string tooltip
    signal clicked

    implicitWidth: size
    implicitHeight: size
    opacity: enabled ? 1 : 0.35
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: tooltip

    Keys.onSpacePressed: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.filled ? "white"
            : mouse.pressed ? Theme.pressed
            : root.toggled ? Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, mouse.containsMouse ? 0.42 : 0.3)
            : mouse.containsMouse ? Theme.hover
            : "transparent"
        scale: mouse.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    // Focus ring
    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Player.accent
        visible: root.activeFocus
    }

    Icon {
        anchors.centerIn: parent
        kind: root.icon
        size: root.iconSize
        color: root.filled ? Qt.darker(Player.tint, 1.2)
            : root.toggled ? "white" : Theme.textTertiary
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
