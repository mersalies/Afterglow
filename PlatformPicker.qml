import QtQuick

// Where the search looks: a pill with the service's badge and name; click for
// the list. The choice is kept in config.json (searchPlatform).
Item {
    id: root

    property bool expanded: false
    implicitWidth: pill.width
    implicitHeight: 40

    Rectangle {
        id: pill
        height: 40
        width: row.implicitWidth + 26
        radius: 20
        readonly property color tone: Player.sourceColor(Catalog.platform)
        color: Qt.rgba(tone.r, tone.g, tone.b, area.containsMouse || root.expanded ? 0.32 : 0.22)
        border.width: 1
        border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.65)
        Behavior on color { ColorAnimation { duration: 160 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 8
            PlatformBadge {
                anchors.verticalCenter: parent.verticalCenter
                platform: Catalog.platform
                size: 26
                glow: true
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Catalog.platformName(Catalog.platform)
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                kind: "up"
                size: 16
                color: Theme.textSecondary
                rotation: root.expanded ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 180 } }
            }
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    // The list opens upwards, over the results.
    Glass {
        id: list
        y: -height - 8
        width: 230
        height: col.implicitHeight + 12
        radius: 16
        color: Theme.menuColor(0.97)
        visible: opacity > 0.01
        opacity: root.expanded ? 1 : 0
        scale: root.expanded ? 1 : 0.94
        transformOrigin: Item.BottomLeft
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

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
                        onClicked: { Config.searchPlatform = modelData[0]; root.expanded = false; }
                    }
                }
            }
        }
    }
}
