import QtQuick

// Left panel: what plays next, what played before, and the library of the
// service pinned at the transport bar's badge (Spotify when none or YouTube is).
Glass {
    id: root

    // "next" | "history" | "library"
    property string tab: "history"
    // No glass sheet: rows float on the field, the playing one raised as a card.
    property bool floating: false

    signal builderRequested

    sheen: !floating
    border.color: floating ? "transparent" : Qt.rgba(1, 1, 1, 0.12)
    clip: false

    function isNow(t) { return t.title === Player.title && t.artist === Player.artist; }

    // ---- The library tab follows the pinned service
    readonly property var libServices: ["spotify", "soundcloud", "youtube-music", "apple", "yandex", "vk"]
    readonly property string service: libServices.includes(Config.source) ? Config.source : "spotify"
    readonly property string serviceLabel: ({ "youtube-music": "YT Music", "yandex": "Яндекс", "vk": "VK" })[service]
                                           ?? Player.sourceName(service, null)
    // Services with no open API: Afterglow only follows them as they play.
    readonly property bool closedService: ["apple", "yandex", "vk"].includes(service)

    // What played on this service, newest first, once each.
    readonly property var serviceHistory: {
        const seen = new Set();
        return History.tracks.filter(h => h.source === service && !seen.has(h.title + "\u0001" + h.artist)
                                          && seen.add(h.title + "\u0001" + h.artist));
    }

    // Rows of the library (not Spotify, which has its own below).
    readonly property var lists: {
        const out = [];
        if (service === "soundcloud") {
            if (Accounts.scLikes.length)
                out.push({ kind: "list", id: "sc-likes", title: "Лайки", sub: Accounts.scLikes.length + " треков",
                           art: Accounts.scLikes.find(t => t.art)?.art ?? "", tracks: Accounts.scLikes });
            for (const a of Accounts.scSets)
                out.push({ kind: "set", id: a.id, title: a.title, sub: (a.mine ? "Плейлист" : "Альбом") + "  ·  " + a.sub, art: a.art, uri: a.uri });
        } else if (service === "youtube-music" && Accounts.ytmLiked.length) {
            out.push({ kind: "list", id: "ytm-liked", title: "Понравившиеся", sub: Accounts.ytmLiked.length + " треков",
                       art: Accounts.ytmLiked[0].art, tracks: Accounts.ytmLiked });
        }
        const played = serviceHistory.filter(h => h.uri);
        if (!closedService && played.length)
            out.push({ kind: "list", id: "history", title: "Из истории", sub: played.length + " треков", art: played[0].art, tracks: played });
        return out;
    }

    // An open list or album: { id, title, sub, art, tracks, loading, message }
    property var openList: null
    onServiceChanged: openList = null
    function openRow(r) {
        if (r.kind !== "set") {
            openList = { id: r.id, title: r.title, sub: r.sub, art: r.art, tracks: r.tracks, loading: false, message: "", uri: "" };
            return;
        }
        openList = { id: r.id, title: r.title, sub: r.sub, art: r.art, tracks: [], loading: true, message: "", uri: r.uri };
        Accounts.scSet(r.uri, d => {
            if (root.openList?.id !== r.id) return;
            const tracks = (d?.tracks ?? []).map(t => Object.assign({}, t, { art: t.art || d.art || r.art }));
            const more = d?.more === true;
            root.openList = Object.assign({}, root.openList, {
                // Tracks closed in the listener's region are left out of the set by SoundCloud.
                tracks, loading: more && !tracks.length, more,
                message: tracks.length || more ? "" : d ? "SoundCloud не отдаёт треки этого альбома: скорее всего, они закрыты в твоём регионе. Его можно открыть на сайте: кнопка с нотой вверху."
                                                                       : "Не удалось загрузить альбом"
            });
        });
    }
    function shuffled(list) {
        const a = list.slice();
        for (let i = a.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [a[i], a[j]] = [a[j], a[i]];
        }
        return a;
    }
    readonly property string emptyText: {
        if (service === "soundcloud")
            return !Accounts.scName ? "Укажи свой профиль SoundCloud в настройках, во вкладке «Аккаунты»: здесь появятся твои лайки и альбомы."
                 : Accounts.scStatus === "checking" ? "Загружаю лайки и альбомы…"
                 : Accounts.scStatus === "error" ? "Профиль не найден или лайки скрыты."
                 : "В профиле пока нет лайков.";
        if (service === "youtube-music")
            return !Config.youtubeCookies ? "Выбери браузер, где ты вошёл в YouTube Music, в настройках, во вкладке «Аккаунты»: здесь появятся понравившиеся треки."
                 : Accounts.ytmStatus === "checking" ? "Загружаю понравившиеся…"
                 : "Не получилось загрузить понравившиеся треки.";
        return "";
    }

    // Segmented tabs
    Rectangle {
        id: tabs
        x: 12
        y: 12
        width: parent.width - 24
        height: 36
        radius: 18
        // Floating over the clock: solid enough that the digits pass under it.
        color: root.floating ? Qt.rgba(Player.tint.r * 0.45, Player.tint.g * 0.45, Player.tint.b * 0.45, 0.9 * Config.panelOpacity)
                             : Qt.rgba(0, 0, 0, 0.22 * Config.panelOpacity)
        border.width: root.floating ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.1)

        readonly property var names: [["next", "Далее"], ["history", "История"], ["library", root.serviceLabel]]
        readonly property real seg: width / names.length

        Rectangle {
            y: 3
            height: parent.height - 6
            width: tabs.seg - 6
            radius: height / 2
            x: 3 + tabs.seg * tabs.names.findIndex(n => n[0] === root.tab)
            color: Qt.rgba(1, 1, 1, 0.14)
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        Row {
            anchors.fill: parent
            Repeater {
                model: tabs.names
                Item {
                    required property var modelData
                    width: tabs.seg
                    height: tabs.height
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: modelData[1]
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: root.tab === modelData[0] ? Theme.text : Theme.textSecondary
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.tab = modelData[0]
                    }
                }
            }
        }
    }

    Item {
        id: body
        anchors.top: tabs.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 8
        anchors.rightMargin: 8
        clip: true

        component Hint: Text {
            anchors.centerIn: parent
            width: parent.width - 32
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: 13
            lineHeight: 1.3
            color: Theme.textSecondary
        }

        component TrackList: ListView {
            anchors.fill: parent
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 300 } }
            displaced: Transition { NumberAnimation { properties: "y"; duration: 300; easing.type: Easing.OutCubic } }
        }

        // ---- Next: Afterglow's queue
        QueueList {
            anchors.fill: parent
            visible: root.tab === "next"
            onAddRequested: root.builderRequested()
        }

        // ---- History
        Item {
            anchors.fill: parent
            visible: root.tab === "history"

            TrackList {
                model: History.tracks
                delegate: TrackRow {
                    required property var modelData
                    width: ListView.view.width
                    title: modelData.title
                    subtitle: [modelData.artist, Player.sourceName(modelData.source, null)].filter(s => s).join("  ·  ")
                    art: modelData.art
                    active: root.isNow(modelData)
                    glassActive: root.floating
                    queueable: (modelData.uri ?? "") !== ""
                    nextable: (modelData.uri ?? "") !== ""
                    onQueued: Queue.add(modelData)
                    onQueuedNext: Queue.addNext(modelData)
                    onClicked: if (!active) History.play(modelData)
                }
            }
            Hint {
                visible: History.tracks.length === 0
                text: "Здесь появятся треки, которые ты слушаешь."
            }
        }

        // ---- Spotify
        Item {
            anchors.fill: parent
            visible: root.tab === "library" && root.service === "spotify"

            SpotifyConnect {
                anchors.fill: parent
                anchors.margins: 8
                visible: !Spotify.connected
            }

            // Playlists
            ListView {
                anchors.fill: parent
                visible: Spotify.connected && !Spotify.openList
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: [{ id: "liked", name: "Любимые треки", image: "", count: Spotify.liked.length }].concat(Spotify.playlists)
                delegate: TrackRow {
                    required property var modelData
                    width: ListView.view.width
                    title: modelData.name
                    subtitle: modelData.id !== "liked" ? modelData.count + " треков"
                        : modelData.count ? modelData.count + " треков" : Spotify.limitText ? "Spotify ограничил запросы" : ""
                    art: modelData.image
                    onClicked: Spotify.open(modelData)
                }
                footer: Item {
                    width: ListView.view.width
                    height: 44
                    Text {
                        anchors.centerIn: parent
                        text: "Выйти из Spotify"
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.textTertiary
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Spotify.logout()
                        }
                    }
                }
            }

            // Open playlist
            Item {
                anchors.fill: parent
                visible: Spotify.connected && Spotify.openList !== null

                Row {
                    id: head
                    height: 36
                    spacing: 4
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "back"
                        size: 32
                        tooltip: "Назад"
                        onClicked: Spotify.openList = null
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: body.width - 44
                        elide: Text.ElideRight
                        text: Spotify.openList?.name ?? ""
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }

                // Play the whole list in Spotify (also works where the API hides the tracks).
                Row {
                    id: pills
                    anchors.top: head.bottom
                    anchors.topMargin: 6
                    x: 4
                    spacing: 6
                    visible: (Spotify.openList?.uri ?? "") !== ""
                    Pill { icon: "play"; label: "Играть"; onClicked: Spotify.playContext(Spotify.openList.uri, false) }
                    Pill { icon: "refresh"; label: "Перемешать"; onClicked: Spotify.playContext(Spotify.openList.uri, true) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (Spotify.openList?.tracks?.length ?? 0) > 0
                        text: (Spotify.openList?.tracks?.length ?? 0) + (Spotify.openList?.loading ? "…" : "")
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.textTertiary
                    }
                }

                ListView {
                    anchors.top: pills.visible ? pills.bottom : head.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Spotify.openList?.tracks ?? []
                    delegate: TrackRow {
                        required property var modelData
                        width: ListView.view.width
                        title: modelData.title
                        subtitle: modelData.artist
                        art: modelData.art
                        active: root.isNow(modelData)
                    glassActive: root.floating
                        queueable: true
                        nextable: true
                        onQueued: Queue.add(modelData)
                        onQueuedNext: Queue.addNext(modelData)
                        // With nothing queued, play inside the playlist so Spotify carries
                        // on through it; with a queue, play just this track and keep the queue.
                        onClicked: {
                            const ctx = Spotify.openList?.uri ?? "";
                            if (Queue.items.length === 0 && ctx && Spotify.connected) {
                                Queue.release();
                                Spotify.play(modelData.uri, ctx);
                            } else {
                                Queue.playNow(modelData);
                            }
                        }
                    }
                }

                Hint {
                    visible: Spotify.openList && (Spotify.openList.loading || Spotify.openList.message)
                    text: Spotify.openList?.loading ? "Загружаю…" : (Spotify.openList?.message ?? "")
                }
            }
        }
            // ---- SoundCloud, YouTube Music, and the services with no open API
        Item {
            anchors.fill: parent
            visible: root.tab === "library" && root.service !== "spotify"

            // Lists and albums
            ListView {
                anchors.fill: parent
                visible: root.openList === null
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.closedService ? root.serviceHistory : root.lists
                header: Column {
                    width: ListView.view.width
                    visible: root.closedService
                    height: visible ? implicitHeight + 10 : 0
                    spacing: 10
                    Text {
                        x: 8
                        width: parent.width - 16
                        wrapMode: Text.WordWrap
                        text: "У " + Player.sourceName(root.service, null) + " нет открытого доступа к медиатеке: музыка играет "
                              + (root.service === "yandex" ? "в приложении или вкладке браузера" : "во вкладке браузера")
                              + ", а Afterglow показывает её и управляет ей."
                              + (root.serviceHistory.length ? " Ниже то, что ты там слушал." : "")
                        font.family: Theme.font
                        font.pixelSize: 12
                        lineHeight: 1.25
                        color: Theme.textSecondary
                    }
                    Pill {
                        x: 8
                        icon: "music"
                        label: "Открыть " + Player.sourceName(root.service, null)
                        onClicked: Qt.openUrlExternally(Player.defaultPages[root.service])
                    }
                }
                delegate: TrackRow {
                    required property var modelData
                    width: ListView.view.width
                    title: modelData.title
                    subtitle: root.closedService ? modelData.artist : modelData.sub
                    art: modelData.art
                    active: root.closedService && root.isNow(modelData)
                    glassActive: root.floating
                    onClicked: {
                        if (!root.closedService) root.openRow(modelData);
                        else if (modelData.uri) History.play(modelData);
                    }
                }
            }

            Hint {
                visible: root.openList === null && !root.closedService && root.lists.length === 0
                text: root.emptyText
            }

            // Open list or album
            Item {
                anchors.fill: parent
                visible: root.openList !== null

                Row {
                    id: genHead
                    height: 36
                    spacing: 4
                    IconButton {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "back"
                        size: 32
                        tooltip: "Назад"
                        onClicked: root.openList = null
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: body.width - 44 - (siteBtn.visible ? 36 : 0)
                        elide: Text.ElideRight
                        text: root.openList?.title ?? ""
                        font.family: Theme.font
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    IconButton {
                        id: siteBtn
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (root.openList?.uri ?? "") !== ""
                        icon: "music"
                        size: 32
                        tooltip: "Открыть на SoundCloud"
                        onClicked: Qt.openUrlExternally(root.openList.uri)
                    }
                }

                Row {
                    id: genPills
                    anchors.top: genHead.bottom
                    anchors.topMargin: 6
                    x: 4
                    spacing: 6
                    readonly property bool hasTracks: (root.openList?.tracks?.length ?? 0) > 0
                    visible: hasTracks
                    Pill { icon: "play"; label: "Играть"; onClicked: Queue.playAll(root.openList.tracks) }
                    Pill { icon: "refresh"; label: "Перемешать"; onClicked: Queue.playAll(root.shuffled(root.openList.tracks)) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.openList?.tracks?.length ?? 0) + (root.openList?.more ? "…" : "")
                        font.family: Theme.font
                        font.pixelSize: 12
                        color: Theme.textTertiary
                    }
                }

                ListView {
                    anchors.top: genPills.visible ? genPills.bottom : genHead.bottom
                    anchors.topMargin: 6
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    spacing: 2
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.openList?.tracks ?? []
                    delegate: TrackRow {
                        required property var modelData
                        width: ListView.view.width
                        title: modelData.title
                        subtitle: modelData.artist
                        art: modelData.art
                        active: root.isNow(modelData)
                        glassActive: root.floating
                        queueable: true
                        nextable: true
                        onQueued: Queue.add(modelData)
                        onQueuedNext: Queue.addNext(modelData)
                        onClicked: if (!active) Queue.playNow(modelData)
                    }
                }

                Hint {
                    visible: root.openList !== null && (root.openList.loading || root.openList.message !== "")
                    text: root.openList?.loading ? "Загружаю…" : (root.openList?.message ?? "")
                }
            }
        }
    }
}
