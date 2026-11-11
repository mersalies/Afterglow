import QtQuick

// Settings, inside the window above the transport bar, in four tabs:
//   Вид       what the centre shows and when, card size, lyrics font and size,
//             backdrop, panel and menu opacity
//   Часы      where the clock shows (per scene), layer, size, fill, outline
//   Аккаунты  Spotify, YouTube Music, SoundCloud; how Yandex, VK and Apple Music
//             are followed
//   Плеер     default player, music-video quality, autoplay, disk cache
// Every change applies at once and is saved to config.json.
Glass {
    id: root

    property bool open: false
    property real maxHeight: 600
    property string tab: "view"
    // The clock scene on screen now ("Lyrics", "Covers", "Clip"), for the Часы tab.
    property string scene: "Lyrics"
    onOpenChanged: if (open) { Cache.measure(); }

    radius: 18
    width: 360
    height: Math.min(maxHeight, head.height + col.implicitHeight + 48)
    color: Theme.menuColor(0.94)

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    transformOrigin: Item.BottomRight
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

    // Swallow clicks and wheel so nothing behind the menu reacts.
    MouseArea { anchors.fill: parent; onWheel: e => e.accepted = true }

    // ---- Small building blocks

    // A wrap-around choice of options: [[value, label]].
    component Chips: Flow {
        id: chips
        property var options: []
        property string value
        signal picked(string value)
        width: parent ? parent.width : 300
        spacing: 6
        Repeater {
            model: chips.options
            Rectangle {
                required property var modelData
                readonly property bool on: chips.value === modelData[0]
                height: 30
                width: chipText.implicitWidth + 24
                radius: 15
                color: on ? Qt.rgba(1, 1, 1, 0.18) : chipArea.containsMouse ? Theme.hover : Qt.rgba(0, 0, 0, 0.18)
                border.width: 1
                border.color: on ? Qt.rgba(1, 1, 1, 0.32) : Theme.hairline
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: modelData[1]
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: parent.on ? Theme.text : Theme.textSecondary
                }
                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: chips.picked(modelData[0])
                }
            }
        }
    }

    component Note: Text {
        width: parent ? parent.width : 300
        wrapMode: Text.WordWrap
        font.family: Theme.font
        font.pixelSize: 12
        lineHeight: 1.25
        color: Theme.textSecondary
        textFormat: Text.StyledText
        linkColor: Qt.lighter(Player.accent, 1.4)
        onLinkActivated: url => Qt.openUrlExternally(url)
    }

    component Field: Rectangle {
        property alias text: input.text
        property alias placeholder: hint.text
        signal accepted(string text)
        width: parent ? parent.width : 300
        height: 34
        radius: 10
        color: Qt.rgba(0, 0, 0, 0.22)
        border.width: input.activeFocus ? 1 : 0
        border.color: Player.accent
        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.text
            clip: true
            onEditingFinished: parent.accepted(text.trim())
            Text {
                id: hint
                anchors.verticalCenter: parent.verticalCenter
                visible: !input.text
                font: input.font
                color: Theme.textTertiary
            }
        }
    }

    // A row of colour swatches: "accent" (the cover's colour) and fixed colours.
    component Swatches: Flow {
        id: sw
        property string value
        signal picked(string value)
        width: parent ? parent.width : 300
        spacing: 7
        Repeater {
            model: ["accent", "#ffffff", "#c7c7cc", "#1c1c1e", "#000000", "#ff453a", "#ff9f0a", "#ffd60a",
                    "#30d158", "#64d2ff", "#0a84ff", "#5e5ce6", "#bf5af2", "#ff375f"]
            Rectangle {
                required property string modelData
                readonly property bool on: sw.value.toLowerCase() === modelData
                width: 26
                height: 26
                radius: 13
                color: modelData === "accent" ? Player.accent : modelData
                border.width: on ? 2 : 1
                border.color: on ? "white" : Qt.rgba(1, 1, 1, 0.25)
                scale: swArea.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Icon {
                    anchors.centerIn: parent
                    visible: modelData === "accent"
                    kind: "glow"
                    size: 14
                    color: "white"
                }
                MouseArea {
                    id: swArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sw.picked(modelData)
                }
            }
        }
    }

    component Label: Text {
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: Theme.text
    }

    // One service: badge, name, state, then whatever controls it needs.
    component Account: Rectangle {
        id: acc
        property string platform
        property string name
        property string info
        property bool linked: false
        default property alias content: extra.data
        width: parent ? parent.width : 300
        height: accCol.implicitHeight + 24
        radius: 14
        color: Qt.rgba(0, 0, 0, 0.2)
        border.width: 1
        border.color: linked ? Qt.rgba(Player.sourceColor(platform).r, Player.sourceColor(platform).g, Player.sourceColor(platform).b, 0.45)
                             : Theme.hairline
        Column {
            id: accCol
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 10
            Row {
                spacing: 10
                width: parent.width
                PlatformBadge { platform: acc.platform; size: 30; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    width: parent.width - 40
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: acc.name
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: acc.info
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: acc.linked ? Qt.lighter(Player.sourceColor(acc.platform), 1.2) : Theme.textTertiary
                    }
                }
            }
            Column {
                id: extra
                width: parent.width
                spacing: 8
            }
        }
    }

    // ---- Header and tabs

    Column {
        id: head
        x: 16
        y: 16
        width: root.width - 32
        spacing: 12

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
                visible: root.tab !== "accounts"
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
                        if (root.tab === "view") {
                            Config.centerMode = "auto"; Config.cardsShowDelay = 0.3; Config.cardsHideDelay = 5; Config.cardsScale = 1;
                            Config.lyricsFont = ""; Config.lyricsScale = 1;
                            Config.backdropOpacity = 1; Config.backdropBlur = 0.1;
                            Config.panelOpacity = 1; Config.menuOpacity = 1;
                        } else if (root.tab === "clock") {
                            Config.resetClock();
                        } else {
                            Config.defaultPlayer = ""; Config.clipQuality = 480; Config.videoBackground = true;
                            Config.autoplayLiked = true;
                            Config.clipCacheMB = 300; Config.audioCacheMB = 300; Config.artCacheMB = 50;
                        }
                    }
                }
            }
        }

        Segments {
            width: parent.width
            options: [["view", "Вид"], ["clock", "Часы"], ["accounts", "Аккаунты"], ["player", "Плеер"]]
            value: root.tab
            onPicked: v => { root.tab = v; flick.contentY = 0; }
        }
    }

    Flickable {
        id: flick
        x: 16
        anchors.top: head.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: root.width - 32
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            spacing: 6

            // ================= Вид

            Column {
                width: parent.width
                spacing: 6
                visible: root.tab === "view"

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
                SettingSlider {
                    label: "Размер карточек"; from: 0.6; to: 1.8; unit: "×"
                    value: Config.cardsScale; onChanged: v => Config.cardsScale = v
                }

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
                Field {
                    id: fontFilter
                    placeholder: "Найти шрифт…"
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

                SettingHeading { text: "Фон (обложка или клип)" }
                SettingSlider {
                    label: "Яркость фона"; from: 0; to: 1
                    value: Config.backdropOpacity; onChanged: v => Config.backdropOpacity = v
                }
                SettingSlider {
                    label: "Размытие фона"; from: 0; to: 1
                    value: Config.backdropBlur; onChanged: v => Config.backdropBlur = v
                }

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
            }

            // ================= Часы

            Column {
                width: parent.width
                spacing: 6
                visible: root.tab === "clock"

                SettingHeading { text: "Где показывать" }
                Note {
                    text: "У каждой сцены свои часы. Перетащи их мышью куда нужно, двойной щелчок вернёт на место. Сейчас: <b>"
                        + ({ Lyrics: "текст", Covers: "обложки", Clip: "клип" })[root.scene] + "</b>."
                }
                SettingSwitch {
                    label: "В режиме текста"
                    checked: Config.clockShowLyrics
                    onToggled: c => Config.clockShowLyrics = c
                }
                SettingSwitch {
                    label: "В режиме обложек"
                    checked: Config.clockShowCovers
                    onToggled: c => Config.clockShowCovers = c
                }
                SettingSwitch {
                    label: "Когда на фоне клип"
                    checked: Config.clockShowClip
                    onToggled: c => Config.clockShowClip = c
                }
                Pill {
                    icon: "refresh"
                    label: "Вернуть часы на место"
                    onClicked: {
                        for (const k of ["Lyrics", "Covers", "Clip"]) { Config["clock" + k + "X"] = -1; Config["clock" + k + "Y"] = -1; }
                    }
                }

                SettingHeading { text: "Слой и размер" }
                Segments {
                    width: parent.width
                    options: [["back", "Под текстом"], ["front", "Поверх всего"]]
                    value: Config.clockLayer
                    onPicked: v => Config.clockLayer = v
                }
                SettingSlider {
                    label: "Размер"; from: 0.4; to: 2.5; unit: "×"
                    value: Config.clockScale; onChanged: v => Config.clockScale = v
                }

                SettingHeading { text: "Цвет цифр" }
                Segments {
                    width: parent.width
                    options: [["auto", "По обложке"], ["solid", "Цвет"], ["gradient", "Градиент"]]
                    value: Config.clockFill
                    onPicked: v => Config.clockFill = v
                }
                Label { visible: Config.clockFill === "gradient"; text: "Сверху / с начала" }
                Swatches {
                    visible: Config.clockFill !== "auto"
                    value: Config.clockColor
                    onPicked: v => Config.clockColor = v
                }
                Label { visible: Config.clockFill === "gradient"; text: "Снизу / к концу" }
                Swatches {
                    visible: Config.clockFill === "gradient"
                    value: Config.clockColor2
                    onPicked: v => Config.clockColor2 = v
                }
                Segments {
                    width: parent.width
                    visible: Config.clockFill === "gradient" || Config.clockOutlineGradient
                    options: [["90", "Сверху вниз"], ["0", "Слева направо"], ["45", "Наискосок"]]
                    value: String(Math.round(Config.clockAngle))
                    onPicked: v => Config.clockAngle = parseInt(v)
                }

                SettingHeading { text: "Обводка" }
                SettingSlider {
                    label: "Толщина"; from: 0; to: 12; unit: " px"; decimals: 1
                    value: Config.clockOutline; onChanged: v => Config.clockOutline = Math.round(v * 2) / 2
                }
                Swatches {
                    visible: Config.clockOutline > 0
                    value: Config.clockOutlineColor
                    onPicked: v => Config.clockOutlineColor = v
                }
                SettingSwitch {
                    visible: Config.clockOutline > 0
                    label: "Обводка градиентом"
                    checked: Config.clockOutlineGradient
                    onToggled: c => Config.clockOutlineGradient = c
                }
                Swatches {
                    visible: Config.clockOutline > 0 && Config.clockOutlineGradient
                    value: Config.clockOutlineColor2
                    onPicked: v => Config.clockOutlineColor2 = v
                }
            }

            // ================= Аккаунты

            Column {
                width: parent.width
                spacing: 10
                visible: root.tab === "accounts"

                Note {
                    topPadding: 4
                    text: "Пароли Afterglow не хранит: Spotify входит через свой сайт, YouTube — через вход в твоём браузере."
                }

                Account {
                    platform: "spotify"
                    name: "Spotify"
                    linked: Spotify.connected
                    info: Spotify.connected && Spotify.limitText ? Spotify.limitText
                        : Spotify.connected ? "Подключён · " + Spotify.playlists.length + " плейлистов, " + Spotify.liked.length + " любимых"
                        : Spotify.status === "signing-in" ? "Жду вход в браузере…"
                        : Spotify.status === "error" ? (Spotify.error || "Ошибка входа")
                        : "Не подключён"

                    Note {
                        visible: !Spotify.connected
                        text: "Даёт плейлисты, любимые треки, поиск и очередь Spotify. Нужен свой Client ID: создай приложение на "
                            + "<a href=\"https://developer.spotify.com/dashboard\">developer.spotify.com</a> "
                            + "с Redirect URI <b>" + Spotify.redirectUri + "</b>."
                    }
                    Field {
                        visible: !Spotify.connected
                        placeholder: "Client ID"
                        text: Config.spotifyClientId
                        onAccepted: t => Config.spotifyClientId = t
                    }
                    Pill {
                        visible: !Spotify.connected && Spotify.status !== "signing-in"
                        icon: "check"
                        label: "Войти через браузер"
                        opacity: Config.spotifyClientId ? 1 : 0.4
                        onClicked: Spotify.login()
                    }
                    Pill {
                        visible: Spotify.connected
                        icon: "close"
                        label: "Отключить"
                        onClicked: Spotify.logout()
                    }
                }

                Account {
                    platform: "youtube-music"
                    name: "YouTube Music и YouTube"
                    linked: Accounts.ytmStatus === "ok"
                    readonly property string browser: (Config.youtubeCookies || "").replace(/^\w/, c => c.toUpperCase())
                    info: Accounts.ytmStatus === "ok" ? "Вход через " + browser + " · " + Accounts.ytmLiked.length + " понравившихся"
                        : Accounts.ytmStatus === "checking" ? "Проверяю вход в " + browser + "…"
                        : Accounts.ytmStatus === "error" ? "Не вышло: войди на music.youtube.com в " + browser
                        : "Без входа"

                    Note {
                        text: "Afterglow берёт вход из браузера, где ты уже вошёл в YouTube: понравившиеся треки попадают в библиотеку и автоплей, а клипы качаются без проверки «я не бот»."
                    }
                    Chips {
                        options: [["", "Нет"], ["firefox", "Firefox"], ["chromium", "Chromium"], ["chrome", "Chrome"], ["brave", "Brave"], ["vivaldi", "Vivaldi"]]
                        value: Config.youtubeCookies
                        onPicked: v => Config.youtubeCookies = v
                    }
                }

                Account {
                    platform: "soundcloud"
                    name: "SoundCloud"
                    linked: Accounts.scStatus === "ok"
                    info: Accounts.scStatus === "ok" ? Accounts.scName + " · " + Accounts.scLikes.length + " лайков, " + Accounts.scSets.length + " альбомов"
                        : Accounts.scStatus === "checking" ? "Загружаю лайки…"
                        : Accounts.scStatus === "error" ? "Профиль не найден или лайки скрыты"
                        : "Не указан"
                    Note { text: "Имя профиля из ссылки soundcloud.com/<b>имя</b>. Лайки должны быть открыты." }
                    Field {
                        placeholder: "Имя профиля или ссылка"
                        text: Config.soundcloudUser
                        onAccepted: t => Config.soundcloudUser = t
                    }
                }

                Repeater {
                    model: [
                        ["yandex", "Яндекс Музыка", "https://music.yandex.ru", "приложение Яндекс Музыки или вкладка music.yandex.ru"],
                        ["vk", "VK Музыка", "https://vk.com/audio", "вкладка vk.com/audio в браузере"],
                        ["apple", "Apple Music", "https://music.apple.com", "вкладка music.apple.com в браузере"]
                    ]
                    Account {
                        required property var modelData
                        platform: modelData[0]
                        name: modelData[1]
                        readonly property bool open: Player.sources.some(s => s.key === modelData[0])
                        linked: open
                        info: open ? "Открыт сейчас · Afterglow следит за ним" : "Через браузер или приложение"
                        Note {
                            text: "Открытого API для входа нет. Слушай через " + modelData[3]
                                + " — Afterglow увидит трек, покажет текст, обложку и клип, а кнопки будут управлять им."
                        }
                        Pill {
                            icon: "play"
                            label: "Открыть"
                            onClicked: Qt.openUrlExternally(modelData[2])
                        }
                    }
                }
            }

            // ================= Плеер

            Column {
                width: parent.width
                spacing: 6
                visible: root.tab === "player"

                SettingHeading { text: "Плеер по умолчанию" }
                Note { text: "Когда ничего не играет, Afterglow показывает этот плеер, а кнопка Play запускает его." }
                Chips {
                    options: [["", "Последний"], ["spotify", "Spotify"], ["youtube-music", "YouTube Music"], ["yandex", "Яндекс Музыка"],
                              ["vk", "VK Музыка"], ["soundcloud", "SoundCloud"], ["afterglow", "Своя очередь"]]
                    value: Config.defaultPlayer
                    onPicked: v => Config.defaultPlayer = v
                }

                SettingHeading { text: "Клип на фоне" }
                SettingSwitch {
                    label: "Показывать клип, если он есть"
                    checked: Config.videoBackground
                    onToggled: c => Config.videoBackground = c
                }
                Text {
                    text: "Качество клипа"
                    font.family: Theme.font
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    color: Theme.text
                }
                Segments {
                    width: parent.width
                    options: [["144", "144p"], ["480", "480p"], ["720", "720p"], ["1080", "1080p"]]
                    value: String(Config.clipQuality)
                    onPicked: v => Config.clipQuality = parseInt(v)
                }
                Note {
                    text: Config.clipQuality >= 1080 ? "1080p: чётко, но клип весит ~60–120 МБ и дольше качается."
                        : Config.clipQuality >= 720 ? "720p: ~30–60 МБ на клип."
                        : Config.clipQuality <= 144 ? "144p: почти ничего не весит; под размытием разница мала."
                        : "480p: ~15–30 МБ на клип, хорошо под размытым фоном."
                }

                SettingHeading { text: "Очередь" }
                SettingSwitch {
                    label: "Когда очередь кончилась — любимые"
                    checked: Config.autoplayLiked
                    onToggled: c => Config.autoplayLiked = c
                }

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
                    label: "Клипы, не больше"; from: 50; to: 4000; unit: " МБ"; decimals: 0
                    value: Config.clipCacheMB; onChanged: v => Config.clipCacheMB = Math.round(v / 50) * 50
                }
                SettingSlider {
                    label: "Звук треков, не больше"; from: 50; to: 4000; unit: " МБ"; decimals: 0
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
            }
            Item { width: 1; height: 6 }
        }
    }
}
