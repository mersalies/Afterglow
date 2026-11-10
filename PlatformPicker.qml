import QtQuick

// Where the search looks: a pill with the service's badge and name; click for
// the list (PlatformMenu, placed by the sheet above everything else so every
// row takes clicks). The choice is kept in config.json (searchPlatform).
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
}
