import QtQuick

// A choice of a few options as a segmented pill.
Rectangle {
    id: seg

    property var options: []     // [[value, label]]
    property string value
    signal picked(string value)

    height: 34
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.22)
    readonly property real w: width / Math.max(1, options.length)

    Rectangle {
        y: 3
        height: parent.height - 6
        width: seg.w - 6
        radius: height / 2
        x: 3 + seg.w * Math.max(0, seg.options.findIndex(o => o[0] === seg.value))
        color: Qt.rgba(1, 1, 1, 0.16)
        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    Row {
        anchors.fill: parent
        Repeater {
            model: seg.options
            Item {
                required property var modelData
                width: seg.w
                height: seg.height
                Text {
                    anchors.centerIn: parent
                    text: modelData[1]
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: seg.value === modelData[0] ? Theme.text : Theme.textSecondary
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(modelData[0])
                }
            }
        }
    }
}
