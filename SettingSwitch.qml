import QtQuick

// Labelled on/off switch.
Item {
    id: root

    property string label
    property bool checked: false
    signal toggled(bool checked)

    width: parent ? parent.width : 260
    height: 32

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: Theme.text
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 22
        radius: 11
        color: root.checked ? Player.accent : Qt.rgba(1, 1, 1, 0.16)
        Behavior on color { ColorAnimation { duration: Theme.quick } }

        Rectangle {
            width: 16
            height: 16
            radius: 8
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
