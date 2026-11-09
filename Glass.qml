import QtQuick

// A raised sheet of glass on the field: faint fill, hairline edge, top sheen.
Rectangle {
    property bool sheen: true

    radius: 22
    color: Qt.rgba(1, 1, 1, 0.07)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.12)

    Rectangle {
        visible: parent.sheen
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.06) }
            GradientStop { position: 0.35; color: "transparent" }
        }
    }
}
