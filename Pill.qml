import QtQuick

// Small rounded action: icon + label.
Rectangle {
    id: pill

    property string icon
    property string label
    signal clicked

    height: 32
    width: row.implicitWidth + 24
    radius: 16
    color: area.containsMouse ? Theme.pressed : Theme.hover

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { anchors.verticalCenter: parent.verticalCenter; kind: pill.icon; size: 15; color: Theme.text }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.label
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: Theme.text
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
