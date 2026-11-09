import QtQuick

// Edge light settings, inside the window above the transport bar. Every change
// applies at once and is saved to config.json.
Glass {
    id: root

    property bool open: false

    radius: 18
    width: 320
    height: col.implicitHeight + 32
    color: Theme.menuColor(0.94)

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    transformOrigin: Item.BottomRight
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    // Swallow clicks and wheel so nothing behind the menu reacts.
    MouseArea { anchors.fill: parent; onWheel: e => e.accepted = true }

    Column {
        id: col
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 6

        Item {
            width: parent.width
            height: 28
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Подсветка экрана"
                font.family: Theme.font
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Сбросить"
                font.family: Theme.font
                font.pixelSize: 12
                color: reset.containsMouse ? Theme.text : Theme.textTertiary
                MouseArea {
                    id: reset
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Config.glowStrength = 1; Config.glowLine = 2.4; Config.glowWidth = 110;
                        Config.glowReact = 1; Config.glowSpeed = 1; Config.glowSparks = 1; Config.glowSparkSize = 1;
                    }
                }
            }
        }

        SettingSwitch { label: "Включена"; checked: Config.glowEnabled; onToggled: c => Config.glowEnabled = c }
        SettingSwitch { label: "Только на мониторе с окном"; checked: Config.glowFollowsWindow; onToggled: c => Config.glowFollowsWindow = c }
        SettingSwitch { label: "Поверх полноэкранных окон"; checked: Config.glowAboveFullscreen; onToggled: c => Config.glowAboveFullscreen = c }
        SettingSwitch { label: "Гореть на паузе"; checked: Config.glowWhenPaused; onToggled: c => Config.glowWhenPaused = c }

        Item { width: 1; height: 4 }

        SettingSlider { label: "Яркость"; from: 0.2; to: 2; value: Config.glowStrength; onChanged: v => Config.glowStrength = v }
        SettingSlider { label: "Толщина линии"; from: 1; to: 5; value: Config.glowLine; unit: " px"; onChanged: v => Config.glowLine = v }
        SettingSlider { label: "Свечение внутрь"; from: 30; to: 260; value: Config.glowWidth; decimals: 0; onChanged: v => Config.glowWidth = Math.round(v) }
        SettingSlider { label: "Реакция на бит"; from: 0; to: 2; value: Config.glowReact; onChanged: v => Config.glowReact = v }
        SettingSlider { label: "Скорость бега"; from: 0.25; to: 3; value: Config.glowSpeed; unit: "×"; onChanged: v => Config.glowSpeed = v }
        SettingSlider { label: "Частицы"; from: 0; to: 3; value: Config.glowSparks; unit: "×"; onChanged: v => Config.glowSparks = v }
        SettingSlider { label: "Размер частиц"; from: 0.5; to: 2.5; value: Config.glowSparkSize; unit: "×"; onChanged: v => Config.glowSparkSize = v }
    }
}
