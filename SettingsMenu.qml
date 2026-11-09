import QtQuick

// General settings, inside the window above the transport bar: what the centre
// shows and when, the lyrics font and size, the backdrop, panel and menu opacity.
// Every change applies at once and is saved to config.json.
Glass {
    id: root

    property bool open: false
    property real maxHeight: 600
    onOpenChanged: if (open) Cache.measure()

    radius: 18
    width: 340
    height: Math.min(maxHeight, col.implicitHeight + 32)
    color: Theme.menuColor(0.94)

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    transformOrigin: Item.BottomRight
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    // Swallow clicks and wheel so nothing behind the menu reacts.
    MouseArea { anchors.fill: parent; onWheel: e => e.accepted = true }

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: root.width - 32
            spacing: 6

            Item {
                width: parent.width
                height: 26
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Настройки"
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
                    color: resetArea.containsMouse ? Theme.text : Theme.textTertiary
                    MouseArea {
                        id: resetArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.centerMode = "auto"; Config.cardsShowDelay = 0.3; Config.cardsHideDelay = 5;
                            Config.lyricsFont = ""; Config.lyricsScale = 1;
                            Config.backdropOpacity = 1; Config.backdropBlur = 0.1;
                            Config.panelOpacity = 1; Config.menuOpacity = 1;
                            Config.clipCacheMB = 300; Config.audioCacheMB = 300; Config.artCacheMB = 50;
                        }
                    }
                }
            }

            // ---- Centre
            SettingHeading { text: "Центр экрана" }
            Segments {
                width: parent.width
                options: [["lyrics", "Текст"], ["auto", "Авто"], ["cards", "Карточки"]]
                value: Config.centerMode
                onPicked: v => Config.centerMode = v
            }
            SettingSlider {
                visible: Config.centerMode === "auto"
                label: "Карточки появляются через"; from: 0; to: 3; unit: " с"
                value: Config.cardsShowDelay; onChanged: v => Config.cardsShowDelay = v
            }
            SettingSlider {
                visible: Config.centerMode === "auto"
                label: "Текст возвращается через"; from: 1; to: 30; unit: " с"; decimals: 0
                value: Config.cardsHideDelay; onChanged: v => Config.cardsHideDelay = Math.round(v)
            }

            // ---- Lyrics text
            SettingHeading { text: "Текст в центре" }
            SettingSlider {
                label: "Размер"; from: 0.5; to: 1.8; unit: "×"
                value: Config.lyricsScale; onChanged: v => Config.lyricsScale = v
            }

            Text {
                text: "Шрифт"
                font.family: Theme.font
                font.pixelSize: 13
                font.weight: Font.DemiBold
                color: Theme.text
            }
            Rectangle {
                width: parent.width
                height: 34
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.22)
                border.width: fontFilter.activeFocus ? 1 : 0
                border.color: Player.accent
                TextInput {
                    id: fontFilter
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.text
                    clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !fontFilter.text
                        text: "Найти шрифт…"
                        font: fontFilter.font
                        color: Theme.textTertiary
                    }
                }
            }

            ListView {
                id: fonts
                width: parent.width
                height: 190
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                // The bundled face first, then everything installed, filtered.
                readonly property var all: [""].concat(Qt.fontFamilies().filter(f => !/emoji|symbol|math|mono|icons|awesome|nerd/i.test(f)))
                model: all.filter(f => !fontFilter.text || (f || Theme.bundledDisplay).toLowerCase().includes(fontFilter.text.toLowerCase()))
                delegate: Item {
                    required property string modelData
                    readonly property bool selected: Config.lyricsFont === modelData
                    width: fonts.width
                    height: 40
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: parent.selected ? Qt.rgba(1, 1, 1, 0.14) : fontArea.containsMouse ? Theme.hover : "transparent"
                    }
                    Text {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 20
                        elide: Text.ElideRight
                        text: (parent.modelData || Theme.bundledDisplay) + "  ·  Текст песни"
                        font.family: parent.modelData || Theme.bundledDisplay
                        font.pixelSize: 17
                        color: Theme.text
                    }
                    MouseArea {
                        id: fontArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Config.lyricsFont = parent.modelData
                    }
                }
            }

            // ---- Backdrop
            SettingHeading { text: "Фон (обложка или клип)" }
            SettingSlider {
                label: "Яркость фона"; from: 0; to: 1
                value: Config.backdropOpacity; onChanged: v => Config.backdropOpacity = v
            }
            SettingSlider {
                label: "Размытие фона"; from: 0; to: 1
                value: Config.backdropBlur; onChanged: v => Config.backdropBlur = v
            }

            // ---- Opacity
            SettingHeading { text: "Прозрачность" }
            SettingSlider {
                label: "Панель слева"; from: 0; to: 1
                value: Config.panelOpacity; onChanged: v => Config.panelOpacity = v
            }
            SettingSlider {
                label: "Меню"; from: 0.3; to: 1
                value: Config.menuOpacity; onChanged: v => Config.menuOpacity = v
            }
            SettingSlider {
                label: "Стекло окна"; from: 0; to: 1
                value: Config.glassOpacity; onChanged: v => Config.glassOpacity = v
            }

            // ---- Disk cache
            SettingHeading { text: "Кэш на диске" }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: "Клипы " + Math.round(Cache.clipsMB) + " МБ · звук " + Math.round(Cache.audioMB)
                    + " МБ · обложки " + Math.round(Cache.artMB) + " МБ"
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textSecondary
            }
            SettingSlider {
                label: "Клипы, не больше"; from: 50; to: 2000; unit: " МБ"; decimals: 0
                value: Config.clipCacheMB; onChanged: v => Config.clipCacheMB = Math.round(v / 50) * 50
            }
            SettingSlider {
                label: "Звук треков, не больше"; from: 50; to: 2000; unit: " МБ"; decimals: 0
                value: Config.audioCacheMB; onChanged: v => Config.audioCacheMB = Math.round(v / 50) * 50
            }
            SettingSlider {
                label: "Обложки, не больше"; from: 10; to: 500; unit: " МБ"; decimals: 0
                value: Config.artCacheMB; onChanged: v => Config.artCacheMB = Math.round(v / 10) * 10
            }
            Pill {
                icon: "close"
                label: "Очистить кэш"
                onClicked: Cache.clear()
            }
            Item { width: 1; height: 6 }
        }
    }
}
