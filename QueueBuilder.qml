import QtQuick

// Queue builder, inside the window: search Spotify, YouTube and SoundCloud at
// once (or paste a link), then play a result now, play it next, or add it to the
// end. The queue itself sits on the right and can be reordered there.
Item {
    id: root

    property bool open: false
    // "all" | "spotify" | "youtube" | "soundcloud"
    property string filter: "all"

    function show(text) {
        open = true;
        coll = null;
        if (text !== undefined && text !== "") {
            input.text = text;
            Search.run(text);
        } else {
            input.text = "";
            Search.run("");
        }
        input.forceActiveFocus();
    }
    function hide() {
        open = false;
        input.focus = false;
    }

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 220 } }

    // ---- Browsing (empty search): your Spotify playlists and albums, and the
    // SoundCloud tracks from the history. A playlist or album opens in place.

    readonly property bool browsing: Search.query === ""
    property var coll: null   // { title, kind, id, art, uri, tracks, loading }

    function openColl(c) {
        coll = { title: c.title, kind: c.kind, id: c.id, art: c.art, uri: c.uri ?? "", tracks: [], loading: true };
        Spotify.collect({ kind: c.kind, id: c.id, image: c.art, name: c.title }, tracks => {
            if (coll && coll.id === c.id) coll = Object.assign({}, coll, { tracks, loading: false });
        });
    }
    function withColl(c, fn) {
        Spotify.collect({ kind: c.kind, id: c.id, image: c.art, name: c.title }, tracks => {
            if (tracks.length) fn(tracks);
            else if (c.uri) Spotify.playContext(c.uri, false);
        });
    }

    readonly property var browseRows: {
        const out = [];
        if (coll) {
            for (const t of coll.tracks) out.push(Object.assign({ group: coll.title, type: "track" }, t));
            return out;
        }
        if (Spotify.connected) {
            const pl = "Spotify · плейлисты", al = "Spotify · альбомы";
            out.push({ group: pl, type: "coll", kind: "liked", id: "liked", title: "Любимые треки", artist: Spotify.liked.length + " треков", art: "" });
            for (const p of Spotify.playlists)
                out.push({ group: pl, type: "coll", kind: "playlist", id: p.id, title: p.name, artist: p.count + " треков", art: p.image, uri: p.uri });
            for (const a of Spotify.albums)
                out.push({ group: al, type: "coll", kind: "album", id: a.id, title: a.name, artist: a.artist, art: a.image, uri: a.uri });
        }
        const seen = new Set();
        for (const h of History.tracks) {
            if (h.source !== "soundcloud" || !h.uri || seen.has(h.uri)) continue;
            seen.add(h.uri);
            out.push(Object.assign({ group: "SoundCloud · из истории", type: "track" }, h));
        }
        return out;
    }

    // Results grouped by service, as one flat model with a section per service.
    readonly property var groups: [
        { key: "link", name: "По ссылке", items: Search.link },
        { key: "spotify", name: "Spotify", items: Search.spotify },
        { key: "youtube", name: "YouTube", items: Search.youtube },
        { key: "soundcloud", name: "SoundCloud", items: Search.soundcloud }
    ]
    readonly property var rows: {
        const out = [];
        for (const g of groups) {
            if (filter !== "all" && g.key !== filter && g.key !== "link") continue;
            for (const t of g.items.slice(0, filter === "all" ? 6 : 30)) out.push(Object.assign({ group: g.name }, t));
        }
        return out;
    }

    // Dim the window behind; click outside to close.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.45
        MouseArea { anchors.fill: parent; onClicked: root.hide() }
    }

    Glass {
        id: panel
        anchors.centerIn: parent
        width: Math.min(1100, parent.width - 64)
        height: Math.min(760, parent.height - 80)
        radius: 26
        color: Theme.menuColor(0.94)
        scale: root.open ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // Swallow clicks so they do not reach the dimmer.
        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: root.hide()

        readonly property real split: width * 0.58

        // ---- Left: search

        Item {
            id: left
            x: 24
            y: 20
            width: panel.split - 36
            height: parent.height - 40

            Text {
                id: heading
                text: "Собрать очередь"
                font.family: Theme.font
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: Theme.text
            }

            Rectangle {
                id: field
                anchors.top: heading.bottom
                anchors.topMargin: 14
                width: parent.width
                height: 46
                radius: 23
                color: Qt.rgba(0, 0, 0, 0.25)
                border.width: input.activeFocus ? 2 : 1
                border.color: input.activeFocus ? Player.accent : Theme.hairline

                Icon {
                    id: glassIcon
                    x: 16
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "search"
                    size: 18
                    color: Theme.textTertiary
                }
                TextInput {
                    id: input
                    anchors.left: glassIcon.right
                    anchors.leftMargin: 10
                    anchors.right: busyText.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: 15
                    color: Theme.text
                    selectionColor: Player.accent
                    selectedTextColor: "black"
                    clip: true
                    onTextChanged: debounce.restart()
                    Keys.onEscapePressed: root.hide()
                    Keys.onReturnPressed: { debounce.stop(); Search.run(text); }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !input.text
                        text: "Трек, исполнитель или ссылка (Spotify, YouTube, SoundCloud…)"
                        font: input.font
                        color: Theme.textTertiary
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
                Text {
                    id: busyText
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: Search.busy ? "Ищу…" : ""
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: Theme.textTertiary
                }
                Timer {
                    id: debounce
                    interval: 500
                    onTriggered: Search.run(input.text)
                }
            }

            // Service filter
            Row {
                id: chips
                anchors.top: field.bottom
                anchors.topMargin: 12
                spacing: 6
                visible: !root.browsing
                Repeater {
                    model: [["all", "Все"], ["spotify", "Spotify"], ["youtube", "YouTube"], ["soundcloud", "SoundCloud"]]
                    Rectangle {
                        required property var modelData
                        readonly property bool on: root.filter === modelData[0]
                        height: 32
                        width: chipText.implicitWidth + 28
                        radius: 16
                        color: on ? Qt.rgba(1, 1, 1, 0.18) : chipArea.containsMouse ? Theme.hover : "transparent"
                        border.width: 1
                        border.color: on ? Qt.rgba(1, 1, 1, 0.3) : Theme.hairline
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData[1]
                            font.family: Theme.font
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            color: parent.on ? Theme.text : Theme.textSecondary
                        }
                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.filter = modelData[0]
                        }
                    }
                }
            }

            // An opened playlist / album: back, play all, queue all.
            Row {
                id: collBar
                anchors.top: field.bottom
                anchors.topMargin: 12
                spacing: 6
                visible: root.browsing && root.coll !== null
                IconButton { icon: "back"; size: 32; tooltip: "Назад"; onClicked: root.coll = null }
                Pill { icon: "play"; label: "Играть всё"; onClicked: { Queue.playAll(root.coll.tracks); root.hide(); } }
                Pill { icon: "plus"; label: "Всё в очередь"; onClicked: Queue.addAll(root.coll.tracks) }
                Pill {
                    visible: (root.coll?.uri ?? "") !== ""
                    icon: "refresh"; label: "Перемешать в Spotify"
                    onClicked: { Spotify.playContext(root.coll.uri, true); root.hide(); }
                }
            }

            ListView {
                id: results
                anchors.top: root.browsing ? (root.coll ? collBar.bottom : field.bottom) : chips.bottom
                anchors.topMargin: 12
                anchors.bottom: parent.bottom
                width: parent.width
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                model: root.browsing ? root.browseRows : root.rows
                section.property: "group"
                section.delegate: Text {
                    required property string section
                    text: section
                    topPadding: 10
                    bottomPadding: 4
                    leftPadding: 8
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }
                delegate: TrackRow {
                    required property var modelData
                    readonly property bool isColl: modelData.type === "coll"
                    width: ListView.view.width
                    title: modelData.title
                    subtitle: [modelData.artist, modelData.length > 0 ? Player.fmt(modelData.length) : ""].filter(s => s).join("  ·  ")
                    art: modelData.art
                    nextable: !isColl
                    queueable: true
                    onClicked: isColl ? root.openColl(modelData) : Queue.playNow(modelData)
                    onQueuedNext: Queue.addNext(modelData)
                    onQueued: isColl ? root.withColl(modelData, tracks => Queue.addAll(tracks)) : Queue.add(modelData)
                }
            }

            Text {
                anchors.centerIn: results
                width: results.width - 40
                visible: (root.browsing ? root.browseRows.length === 0 && !(root.coll?.loading ?? false) : root.rows.length === 0) && !Search.busy
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                lineHeight: 1.3
                text: root.coll ? "Spotify не показывает треки этого плейлиста (чужие плейлисты скрыты с 2026 года). Его можно включить целиком: «Перемешать в Spotify»."
                    : Search.query === "" ? "Ищи сразу на всех площадках. Spotify-треки играют в Spotify, остальные Afterglow играет сам."
                    : !Spotify.connected && root.filter === "spotify" ? "Поиск по Spotify работает после подключения во вкладке «Spotify»."
                    : "Ничего не нашлось"
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.textSecondary
            }
        }

        // ---- Right: the queue

        Rectangle {
            x: panel.split
            y: 20
            width: 1
            height: parent.height - 40
            color: Theme.hairline
        }

        Item {
            x: panel.split + 16
            y: 20
            width: parent.width - x - 20
            height: parent.height - 40

            Text {
                id: qHeading
                text: "Очередь"
                font.family: Theme.font
                font.pixelSize: 20
                font.weight: Font.DemiBold
                color: Theme.text
            }
            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: qHeading.verticalCenter
                icon: "close"
                size: 34
                tooltip: "Закрыть (Esc)"
                onClicked: root.hide()
            }
            QueueList {
                anchors.top: qHeading.bottom
                anchors.topMargin: 14
                anchors.bottom: parent.bottom
                width: parent.width
                onAddRequested: input.forceActiveFocus()
            }
        }
    }
}
