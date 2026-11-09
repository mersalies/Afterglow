import QtQuick

// In-window menu of playback sources: "Automatic" plus every detected player.
Glass {
    id: root

    property bool open: false
    signal picked

    radius: 18
    width: 280
    height: list.implicitHeight + 16
    color: Theme.menuColor(0.92)

    // Swallow clicks and wheel in the gaps so nothing behind the menu reacts.
    MouseArea { anchors.fill: parent; onWheel: e => e.accepted = true }

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    transformOrigin: Item.BottomLeft
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    component Entry: Item {
        id: entry
        property string key
        property string name
        property string sub
        property color dot
        property bool auto: false
        readonly property bool selected: Config.source === key

        width: list.width
        height: sub ? 52 : 44

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: entry.selected ? Qt.rgba(1, 1, 1, 0.12) : mouse.containsMouse ? Theme.hover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        Item {
            id: badge
            x: 12
            width: 22
            height: 22
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.centerIn: parent
                visible: !entry.auto
                width: 12
                height: 12
                radius: 6
                color: entry.dot
            }
            Icon {
                anchors.centerIn: parent
                visible: entry.auto
                kind: "glow"
                size: 18
                color: Theme.textSecondary
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: check.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: entry.name
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: entry.sub
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textSecondary
            }
        }

        Icon {
            id: check
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            kind: "check"
            size: 18
            color: "white"
            opacity: entry.selected ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.quick } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Config.source = entry.key;
                root.picked();
            }
        }
    }

    Column {
        id: list
        x: 8
        y: 8
        width: parent.width - 16
        spacing: 2

        Repeater {
            model: Player.sources
            Entry {
                required property var modelData
                key: modelData.key
                name: modelData.name
                dot: modelData.color
                sub: modelData.playing ? "Играет: " + modelData.title : (modelData.title || "")
            }
        }

        Text {
            width: parent.width
            visible: Player.sources.length === 0
            padding: 12
            wrapMode: Text.WordWrap
            text: "Плееры не найдены. Открой Spotify, Яндекс Музыку или музыку в браузере."
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.textSecondary
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.hairline
        }

        Entry {
            key: "auto"
            name: "Автоматически"
            sub: "То, что играет сейчас"
            auto: true
        }
    }
}
