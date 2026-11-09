import QtQuick

// In-window menu of centre-lyrics animation styles.
Glass {
    id: root

    property bool open: false
    signal picked

    readonly property var entries: [
        ["auto", "Авто", "Новый стиль на каждый трек"],
        ["fly", "Полёт", "Слова влетают из глубины"],
        ["extrude", "Объём и взрыв", "Выпуклые буквы, в конце разлетаются"],
        ["crumble", "Осыпание", "Буквы осыпаются вниз"],
        ["wave", "Волна", "Качаются на басах, прыгают на ударе"],
        ["glitch", "Глитч", "Цветные сбои на ударах"],
        ["neon", "Неон", "Мерцающая вывеска, свечение от басов"],
        ["bounce", "Прыжки", "Падают с отскоком, сжимаются на ударе"]
    ]

    radius: 18
    width: 300
    height: list.implicitHeight + 16
    color: Theme.menuColor(0.92)

    // Swallow clicks and wheel in the gaps so nothing behind the menu reacts.
    MouseArea { anchors.fill: parent; onWheel: e => e.accepted = true }

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    transformOrigin: Item.BottomRight
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    Column {
        id: list
        x: 8
        y: 8
        width: parent.width - 16
        spacing: 2

        Repeater {
            model: root.entries
            Item {
                id: entry
                required property var modelData
                readonly property bool selected: Config.lyricsStyle === modelData[0]
                width: list.width
                height: 50

                Rectangle {
                    anchors.fill: parent
                    radius: 12
                    color: entry.selected ? Qt.rgba(1, 1, 1, 0.12) : area.containsMouse ? Theme.hover : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }
                Column {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                    spacing: 1
                    Text {
                        text: entry.modelData[1]
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: entry.modelData[2]
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.textSecondary
                    }
                }
                Icon {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "check"
                    size: 18
                    color: "white"
                    opacity: entry.selected ? 1 : 0
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Config.lyricsStyle = entry.modelData[0];
                        root.picked();
                    }
                }
            }
        }
    }
}
