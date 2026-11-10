import QtQuick

// The list of search platforms, opening upwards from the PlatformPicker pill.
Glass {
    id: list

    property bool open: false
    signal picked

    width: 230
    height: col.implicitHeight + 12
    radius: 16
    // Opaque whatever the menu opacity: results must not show through.
    color: Qt.rgba(Player.tint.r * 0.45, Player.tint.g * 0.45, Player.tint.b * 0.45, 1)
    visible: opacity > 0.01
    opacity: list.open ? 1 : 0
    scale: list.open ? 1 : 0.94
    transformOrigin: Item.BottomLeft
    Behavior on opacity { NumberAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Gaps between rows must not reach what is behind.
    MouseArea { anchors.fill: parent; hoverEnabled: true }

    Column {
        id: col
        x: 6
        y: 6
        width: parent.width - 12
        Repeater {
            model: Catalog.platforms
            Rectangle {
                required property var modelData
                readonly property bool on: Catalog.platform === modelData[0]
                width: col.width
                height: 42
                radius: 11
                color: on ? Qt.rgba(1, 1, 1, 0.12) : itemArea.containsMouse ? Theme.hover : "transparent"
                Row {
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    PlatformBadge { platform: modelData[0]; size: 26; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData[1]
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: parent.parent.on ? Font.DemiBold : Font.Normal
                        color: Theme.text
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.on
                    kind: "check"
                    size: 16
                    color: Theme.text
                }
                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Config.searchPlatform = modelData[0]; list.picked(); }
                }
            }
        }
    }
}
