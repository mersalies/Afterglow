import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Search, grown out of the search bar above the transport bar. Closed, it is
// that bar: what plays next and the queue count. Click it (or
// Q, /) and the same glass grows up and wide into the results, the field
// staying its bottom row; nothing else on screen is dimmed or covered except
// what it grows over, and a click outside folds it back. Results:
//   artist found   the artist as a card (photo over a blur of it, play their
//                  top songs, or shuffled), top 10 songs, albums and singles
//   no artist      songs and albums
//   album opened   cover, title and buttons on the left, the track list on the right
//   empty query    your library on that service as tiles: Spotify playlists and
//                  albums, liked songs on YouTube Music, SoundCloud likes and history
//   a pasted link  what the link holds
// The service is the one on the transport bar's badge (Catalog.platform), picked
// in its menu; the queue is a button in the field: it slides in on the right.
Item {
    id: root

    property bool open: false
    property bool showQueue: false
    // The closed bar, in our coordinates.
    property real dockX: 0
    property real dockY: height - 160
    property real dockW: 520
    property real dockH: 44

    function show(text) {
        open = true;
        Catalog.closeAlbum();
        input.text = text || "";
        Catalog.run(input.text);
        input.forceActiveFocus();
    }
    function hide() {
        open = false;
        showQueue = false;
        input.focus = false;
    }
    function back() {
        if (Catalog.album) Catalog.closeAlbum();
        else hide();
    }

    readonly property bool browsing: Catalog.query === ""
    readonly property bool linkMode: Catalog.isLink
    readonly property bool busy: Catalog.busy || Search.busy

    // ---- Library (empty query)

    readonly property var library: {
        const out = [];
        if (Spotify.connected) {
            out.push({ group: "Spotify", kind: "liked", id: "liked", title: "Любимые треки", sub: Spotify.liked.length + " треков", art: "", platform: "spotify" });
            for (const p of Spotify.playlists)
                out.push({ group: "Spotify", kind: "playlist", id: p.id, title: p.name, sub: p.count + " треков", art: p.image, uri: p.uri, platform: "spotify" });
            for (const a of Spotify.albums)
                out.push({ group: "Spotify", kind: "album", id: a.id, title: a.name, sub: a.artist, art: a.image, uri: a.uri, platform: "spotify" });
        }
        if (Accounts.ytmLiked.length)
            out.push({ group: "YouTube Music", kind: "list", id: "ytm-liked", title: "Понравившиеся", sub: Accounts.ytmLiked.length + " треков",
                       art: Accounts.ytmLiked[0].art, platform: "youtube-music", tracks: Accounts.ytmLiked });
        if (Accounts.scLikes.length)
            out.push({ group: "SoundCloud", kind: "list", id: "sc-likes", title: "Лайки", sub: Accounts.scLikes.length + " треков",
                       art: "", platform: "soundcloud", tracks: Accounts.scLikes });
        const seen = new Set();
        const scHist = History.tracks.filter(h => h.source === "soundcloud" && h.uri && !seen.has(h.uri) && seen.add(h.uri));
        if (scHist.length)
            out.push({ group: "SoundCloud", kind: "list", id: "sc-history", title: "Из истории", sub: scHist.length + " треков",
                       art: scHist[0].art, platform: "soundcloud", tracks: scHist });
        return out.filter(t => t.platform === Catalog.platform);
    }

    // Library tiles per row and rows: one row or none folds the sheet lower.
    readonly property int libCols: Math.max(1, Math.floor((panel.openW - 28 + 14) / (150 + 14)))
    readonly property int libRows: Math.ceil(library.length / libCols)
    readonly property bool shortSheet: Catalog.album === null && browsing && libRows < 2 && !showQueue

    function openTile(c) {
        Catalog.ticket++;
        if (c.kind === "list") {
            Catalog.album = { id: c.id, title: c.title, artist: c.group, art: c.art, sub: c.sub, about: "",
                              tracks: c.tracks, loading: false, platform: c.platform, uri: "" };
            return;
        }
        const t = Catalog.ticket;
        Catalog.album = { id: c.id, title: c.title, artist: c.kind === "album" ? c.sub : "Spotify", art: c.art,
                          sub: c.kind === "playlist" ? "Плейлист" : c.kind === "album" ? "Альбом" : "Любимые треки",
                          about: "", tracks: [], loading: true, platform: "spotify", uri: c.uri ?? "" };
        Spotify.collect({ kind: c.kind, id: c.id, image: c.art, name: c.title }, tracks => {
            if (t === Catalog.ticket && Catalog.album)
                Catalog.album = Object.assign({}, Catalog.album, { tracks, loading: false });
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

    // A click outside the open sheet folds it back. Nothing is dimmed, and the
    // transport bar below stays live.
    MouseArea {
        width: parent.width
        height: root.dockY + root.dockH
        visible: root.open
        onClicked: root.hide()
    }

    // =====================================================================
    // Building blocks

    // Cover / photo with rounded corners and a placeholder in the platform colour.
    component Cover: ClippingRectangle {
        id: cov
        property string src
        property string platform
        property int texture: 300
        property bool icon: true
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.08)
        Rectangle {
            anchors.fill: parent
            visible: !img.ready
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.darker(Player.sourceColor(cov.platform), 1.6) }
                GradientStop { position: 1; color: Qt.darker(Player.sourceColor(cov.platform), 3.2) }
            }
            Icon {
                anchors.centerIn: parent
                visible: cov.icon
                kind: "music"
                size: parent.width * 0.3
                color: Qt.rgba(1, 1, 1, 0.35)
            }
        }
        CrossfadeImage {
            id: img
            anchors.fill: parent
            source: cov.src || ""
            sourceSize: cov.texture
        }
    }

    // Big primary / secondary buttons (Play, Shuffle).
    component Action: Rectangle {
        id: act
        property string icon
        property string label
        property bool primary: false
        signal clicked
        height: 40
        // Natural width from the label's metrics (not from the row, whose text
        // is clipped to this width: that would be a binding loop).
        TextMetrics { id: actMetrics; font.family: Theme.font; font.pixelSize: 14; font.weight: Font.DemiBold; text: act.label }
        implicitWidth: actMetrics.advanceWidth + 16 + 8 + 32
        width: implicitWidth
        radius: 20
        color: primary ? (actArea.containsMouse ? "#ffffff" : Qt.rgba(1, 1, 1, 0.92))
                       : (actArea.containsMouse ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.13))
        border.width: primary ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
        scale: actArea.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Row {
            id: actRow
            anchors.centerIn: parent
            spacing: 8
            Icon { anchors.verticalCenter: parent.verticalCenter; kind: act.icon; size: 16; color: act.primary ? "#111" : Theme.text }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, act.width - 52)
                elide: Text.ElideRight
                text: act.label
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: act.primary ? "#111" : Theme.text
            }
        }
        MouseArea {
            id: actArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: act.clicked()
        }
    }

    component SectionTitle: Text {
        font.family: Theme.font
        font.pixelSize: 17
        font.weight: Font.Bold
        color: Theme.text
    }

    // One song: number, cover, title, artist / album, length; hover shows
    // "play next" and "add to queue".
    component Song: Item {
        id: song
        property var track
        property int number: 0
        property bool showArt: true
        height: 56
        HoverHandler { id: songHover }
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: songHover.hovered ? Theme.hover : "transparent"
        }
        Text {
            id: num
            x: 6
            width: 22
            anchors.verticalCenter: parent.verticalCenter
            visible: song.number > 0
            horizontalAlignment: Text.AlignRight
            text: song.number
            font.family: Theme.font
            font.pixelSize: 13
            font.features: { "tnum": 1 }
            color: Theme.textTertiary
        }
        Cover {
            id: songArt
            x: song.number > 0 ? 38 : 8
            anchors.verticalCenter: parent.verticalCenter
            visible: song.showArt
            width: song.showArt ? 42 : 0
            height: 42
            radius: 8
            texture: 96
            src: song.track?.art ?? ""
            platform: song.track?.source ?? ""
        }
        Column {
            anchors.left: songArt.right
            anchors.leftMargin: song.showArt ? 12 : 0
            anchors.right: tail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: song.track?.title ?? ""
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: Queue.current?.uri === song.track?.uri ? Qt.lighter(Player.accent, 1.5) : Theme.text
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: [song.track?.artist, song.track?.album].filter(s => s).join("  ·  ")
                font.family: Theme.font
                font.pixelSize: 12
                color: Theme.textSecondary
            }
        }
        Row {
            id: tail
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            IconButton {
                visible: songHover.hovered
                icon: "playnext"; size: 32; tooltip: "Следующим"
                onClicked: Queue.addNext(song.track)
            }
            IconButton {
                visible: songHover.hovered
                icon: "plus"; size: 32; tooltip: "В очередь"
                onClicked: Queue.add(song.track)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !songHover.hovered && (song.track?.length ?? 0) > 0
                text: Player.fmt(song.track?.length ?? 0)
                font.family: Theme.font
                font.pixelSize: 12
                font.features: { "tnum": 1 }
                color: Theme.textTertiary
                rightPadding: 6
            }
        }
        MouseArea {
            id: songArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            z: -1
            onClicked: Queue.playNow(song.track)
        }
    }

    // Songs in two columns (one when narrow), top to bottom then the next column.
    component SongGrid: Item {
        id: grid
        property var list: []
        property bool numbered: true
        readonly property int columns: width >= 540 ? 2 : 1
        readonly property int perColumn: Math.ceil(list.length / columns)
        height: perColumn * 58
        Repeater {
            model: grid.list
            Song {
                required property var modelData
                required property int index
                readonly property int column: index < grid.perColumn ? 0 : 1
                x: column * (grid.width / 2 + 6)
                y: (index - column * grid.perColumn) * 58
                width: grid.columns === 2 ? grid.width / 2 - 6 : grid.width
                track: modelData
                number: grid.numbered ? index + 1 : 0
            }
        }
    }

    // Album / playlist tile: cover and two lines.
    component Tile: Item {
        id: tile
        property var item
        property real size: 150
        signal picked
        width: size
        height: size + 46
        Cover {
            id: tileCover
            width: tile.size
            height: tile.size
            radius: 14
            src: tile.item?.art ?? ""
            platform: tile.item?.platform ?? ""
            icon: !!tile.item?.art
            scale: tileArea.containsMouse ? 1.03 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.5)
                shadowBlur: 0.8
                shadowVerticalOffset: 6
                blurMax: 24
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: !(tile.item?.art)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                text: tile.item?.title ?? ""
                font.family: Theme.display
                font.pixelSize: 18
                color: Qt.rgba(1, 1, 1, 0.85)
            }
        }
        Text {
            y: tile.size + 8
            width: tile.size
            elide: Text.ElideRight
            text: tile.item?.title ?? ""
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Text {
            y: tile.size + 26
            width: tile.size
            elide: Text.ElideRight
            text: tile.item?.sub ?? ""
            font.family: Theme.font
            font.pixelSize: 12
            color: Theme.textSecondary
        }
        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.picked()
        }
    }

    // Grey placeholder that breathes while results load.
    component Skeleton: Rectangle {
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.08)
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            running: root.open && root.busy
            NumberAnimation { to: 0.45; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    // Left column: a blurred copy of the picture, the picture, names, actions.
    component Hero: Item {
        id: hero
        property string image
        property string platform
        property string title
        property string subtitle
        property string about
        property bool round: false
        property var tracks: []
        property bool loading: false
        default property alias actions: actionsRow.data

        ClippingRectangle {
            anchors.fill: parent
            radius: 20
            color: Qt.rgba(0, 0, 0, 0.2)
            CrossfadeImage {
                anchors.fill: parent
                anchors.margins: -40
                source: hero.image || ""
                sourceSize: 256
                blurAmount: 1
                brightness: -0.12
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.05) }
                    GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.25) }
                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.65) }
                }
            }
        }

        Column {
            id: heroCol
            readonly property real restH: heroName.implicitHeight + heroSub.height + 4 + 2
                + (heroAbout.visible ? heroAbout.implicitHeight : 0)
                + (playButtons.visible ? playButtons.implicitHeight : 0)
                + (actionsRow.visibleChildren.length ? actionsRow.implicitHeight : 0)
                + spacing * 7
            x: 16
            width: parent.width - 32
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Cover {
                id: heroCover
                anchors.horizontalCenter: parent.horizontalCenter
                // What is left after the text and buttons (no binding loop: only
                // the other rows' heights count).
                width: Math.max(56, Math.min(parent.width, 220, hero.height - 32 - heroCol.restH))
                height: width
                radius: hero.round ? width / 2 : 18
                texture: 600
                src: hero.image
                platform: hero.platform
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.6)
                    shadowBlur: 1
                    shadowVerticalOffset: 10
                    blurMax: 40
                }
            }
            Item { width: 1; height: 4 }
            Text {
                id: heroName
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: hero.title
                font.family: Theme.display
                font.pixelSize: Math.min(30, Math.max(20, hero.width * 0.09))
                color: Theme.text
            }
            Row {
                id: heroSub
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                PlatformBadge { platform: hero.platform; size: 18; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, hero.width - 70)
                    elide: Text.ElideRight
                    text: hero.subtitle
                    font.family: Theme.font
                    font.pixelSize: 13
                    color: Theme.textSecondary
                }
            }
            Text {
                id: heroAbout
                width: parent.width
                // Only when there is room for it.
                visible: hero.about !== "" && hero.height > 470
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                text: hero.about
                font.family: Theme.font
                font.pixelSize: 12
                lineHeight: 1.25
                color: Theme.textSecondary
            }
            Item { width: 1; height: 2 }
            // Side by side when there is room, one under the other when narrow.
            Grid {
                id: playButtons
                readonly property bool wide: hero.width >= 300
                anchors.horizontalCenter: parent.horizontalCenter
                columns: wide ? 2 : 1
                spacing: 10
                visible: hero.tracks.length > 0
                Action {
                    width: playButtons.wide ? (hero.width - 32 - 10) * 0.44 : hero.width - 48
                    icon: "play"; label: "Играть"; primary: true
                    onClicked: { Queue.playAll(hero.tracks); root.hide(); }
                }
                Action {
                    width: playButtons.wide ? (hero.width - 32 - 10) * 0.56 : hero.width - 48
                    icon: "refresh"; label: "Перемешать"
                    onClicked: { Queue.playAll(root.shuffled(hero.tracks)); root.hide(); }
                }
            }
            Row {
                id: actionsRow
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
            }
        }
    }

    // =====================================================================
    // The sheet

    Glass {
        id: panel
        // About two rows of album tiles high; one row (or the hint) when that is all.
        readonly property real openW: Math.min(920, root.width - 48)
        readonly property real openH: Math.min(root.shortSheet ? (root.libRows ? 290 : 270) : 500, root.dockY + root.dockH - 24)
        // Grows from the bar: its bottom edge stays put.
        x: root.open ? (root.width - openW) / 2 : root.dockX
        y: root.open ? root.dockY + root.dockH - openH : root.dockY
        width: root.open ? openW : root.dockW
        height: root.open ? openH : root.dockH
        Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
        Behavior on width { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
        radius: root.open ? 24 : height / 2
        color: root.open ? Theme.menuColor(0.95) : Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 260 } }
        border.color: !root.open && barHover.hovered ? Qt.rgba(1, 1, 1, 0.26) : Qt.rgba(1, 1, 1, 0.12)
        clip: true

        HoverHandler { id: barHover }
        // Swallow clicks so they do not reach the catcher behind.
        MouseArea { anchors.fill: parent }

        property real pad: root.open ? 14 : 0
        Behavior on pad { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
        property real queueW: root.showQueue ? Math.min(340, width * 0.32) : 0
        Behavior on queueW { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

        // ---- Content above the field
        Item {
            id: content
            x: panel.pad
            y: panel.pad
            width: panel.width - panel.pad * 2 - (panel.queueW > 0 ? panel.queueW + 16 : 0)
            height: footer.y - panel.pad - 12
            opacity: root.open ? 1 : 0
            visible: opacity > 0.01 && height > 60
            Behavior on opacity { NumberAnimation { duration: root.open ? 380 : 120 } }

            // ---------- Album / collection
            Item {
                id: albumView
                anchors.fill: parent
                visible: Catalog.album !== null
                readonly property var album: Catalog.album
                // A real album shows its cover once; playlists and lists keep per-track covers.
                readonly property bool isAlbum: album !== null && (String(album.id).startsWith("MPREb")
                    || /альбом|сингл|сборник|\bEP\b/i.test(album.sub) || /\/sets\//.test(String(album.id)))

                Hero {
                    id: albumHero
                    width: Math.max(230, parent.width * 0.3)
                    height: parent.height
                    image: albumView.album?.art ?? ""
                    platform: albumView.album?.platform ?? ""
                    title: albumView.album?.title ?? ""
                    subtitle: [albumView.album?.artist, albumView.album?.sub].filter(s => s).join("  ·  ")
                    about: albumView.album?.about ?? ""
                    tracks: albumView.album?.tracks ?? []

                    Action {
                        visible: (albumView.album?.tracks.length ?? 0) > 0
                        icon: "plus"; label: "В очередь"
                        onClicked: Queue.addAll(albumView.album.tracks)
                    }
                    Action {
                        visible: (albumView.album?.uri ?? "") !== "" && albumView.album?.platform === "spotify"
                        icon: "refresh"; label: "В Spotify"
                        onClicked: { Spotify.playContext(albumView.album.uri, true); root.hide(); }
                    }
                }

                IconButton {
                    x: 10
                    y: 10
                    icon: "back"
                    size: 36
                    tooltip: "Назад (Esc)"
                    onClicked: Catalog.closeAlbum()
                }

                Item {
                    anchors.left: albumHero.right
                    anchors.leftMargin: 18
                    anchors.right: parent.right
                    height: parent.height

                    SectionTitle {
                        id: albumTitle
                        text: "Треки" + ((albumView.album?.tracks.length ?? 0) ? "  ·  " + albumView.album.tracks.length : "")
                    }
                    ListView {
                        anchors.top: albumTitle.bottom
                        anchors.topMargin: 10
                        anchors.bottom: parent.bottom
                        width: parent.width
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: albumView.album?.tracks ?? []
                        delegate: Song {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            track: modelData
                            number: index + 1
                            showArt: !albumView.isAlbum
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 40
                        spacing: 12
                        visible: albumView.album !== null && !albumView.album.loading && albumView.album.tracks.length === 0
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            text: albumView.album?.platform === "spotify" && albumView.album?.uri
                                ? "Spotify не показывает треки этого плейлиста (чужие плейлисты скрыты с 2026 года). Его можно включить целиком: «В Spotify»."
                                : "Треки не загрузились"
                            font.family: Theme.font
                            font.pixelSize: 13
                            lineHeight: 1.3
                            color: Theme.textSecondary
                        }
                    }
                    Column {
                        anchors.top: albumTitle.bottom
                        anchors.topMargin: 10
                        width: parent.width
                        spacing: 8
                        visible: albumView.album?.loading ?? false
                        Repeater {
                            model: 7
                            Skeleton { width: parent.width; height: 48 }
                        }
                    }
                }
            }

            // ---------- Search results: the artist card, then songs, then albums
            Item {
                id: resultsView
                anchors.fill: parent
                visible: Catalog.album === null && !root.browsing && !root.linkMode

                readonly property bool hasArtist: Catalog.artist !== null

                Hero {
                    id: artistHero
                    visible: resultsView.hasArtist
                    width: resultsView.hasArtist ? Math.max(230, parent.width * 0.28) : 0
                    height: parent.height
                    image: Catalog.artist?.image ?? ""
                    platform: Catalog.platform
                    title: Catalog.artist?.name ?? ""
                    subtitle: Catalog.artist?.sub || Catalog.platformName(Catalog.platform)
                    about: Catalog.artist?.about ?? ""
                    tracks: Catalog.tracks
                }

                Flickable {
                    id: resultsFlick
                    anchors.left: artistHero.right
                    anchors.leftMargin: resultsView.hasArtist ? 18 : 0
                    anchors.right: parent.right
                    height: parent.height
                    contentHeight: resultsCol.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: resultsCol
                        width: resultsFlick.width
                        spacing: 10

                        SectionTitle {
                            visible: Catalog.tracks.length > 0
                            text: resultsView.hasArtist ? "Популярные треки" : Catalog.platform === "youtube" ? "Видео" : "Треки"
                        }
                        SongGrid {
                            width: parent.width
                            list: Catalog.tracks
                            numbered: resultsView.hasArtist
                        }
                        SectionTitle {
                            visible: Catalog.albums.length > 0
                            text: resultsView.hasArtist ? "Альбомы и синглы" : "Альбомы"
                        }
                        ListView {
                            id: albumRow
                            visible: Catalog.albums.length > 0
                            width: parent.width
                            height: 176
                            orientation: ListView.Horizontal
                            spacing: 14
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: Catalog.albums
                            delegate: Tile {
                                required property var modelData
                                item: modelData
                                size: 130
                                onPicked: Catalog.openAlbum(modelData)
                            }
                            WheelHandler {
                                acceptedDevices: PointerDevice.Mouse
                                onWheel: e => albumRow.flick(e.angleDelta.y * 6, 0)
                            }
                        }

                    }
                }

                // Loading: grey tiles and rows in the shape of what is coming.
                Item {
                    anchors.fill: parent
                    visible: root.busy && Catalog.albums.length === 0 && Catalog.tracks.length === 0
                    Grid {
                        id: skelRows
                        columns: 2
                        columnSpacing: 12
                        rowSpacing: 10
                        Repeater { model: 8; Skeleton { width: content.width / 2 - 6; height: 44 } }
                    }
                    Row {
                        anchors.top: skelRows.bottom
                        anchors.topMargin: 30
                        spacing: 14
                        Repeater { model: 6; Skeleton { width: 130; height: 130 } }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 80
                    visible: !root.busy && Catalog.message !== ""
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Catalog.message
                    font.family: Theme.font
                    font.pixelSize: 14
                    color: Theme.textSecondary
                }
            }

            // ---------- A pasted link
            Flickable {
                anchors.fill: parent
                visible: Catalog.album === null && root.linkMode
                contentHeight: linkCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: linkCol
                    width: parent.width
                    spacing: 12
                    SectionTitle { text: Search.linkBusy ? "Открываю ссылку…" : "По ссылке" }
                    Row {
                        spacing: 10
                        visible: Search.link.length > 1
                        Action { icon: "play"; label: "Играть всё"; primary: true; onClicked: { Queue.playAll(Search.link); root.hide(); } }
                        Action { icon: "plus"; label: "Всё в очередь"; onClicked: Queue.addAll(Search.link) }
                    }
                    SongGrid { width: parent.width; list: Search.link; numbered: false }
                }
            }

            // ---------- Library: the chosen service only, two rows of tiles in view
            Flickable {
                id: libFlick
                anchors.fill: parent
                visible: Catalog.album === null && root.browsing
                contentHeight: libFlow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                readonly property real tileSize: Math.max(110, Math.min(160, root.libRows >= 2 ? (height - 14) / 2 - 46 : height - 46))

                Flow {
                    id: libFlow
                    width: libFlick.width
                    spacing: 14
                    Repeater {
                        model: root.library
                        Tile {
                            required property var modelData
                            item: modelData
                            size: libFlick.tileSize
                            onPicked: root.openTile(modelData)
                        }
                    }
                }
            }

            // Nothing in the library on this service: what the search does.
            Column {
                anchors.centerIn: parent
                width: Math.min(460, parent.width - 40)
                spacing: 10
                visible: Catalog.album === null && root.browsing && root.library.length === 0
                PlatformBadge {
                    anchors.horizontalCenter: parent.horizontalCenter
                    platform: Catalog.platform
                    size: 44
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: "Поиск в " + Catalog.platformName(Catalog.platform)
                    font.family: Theme.display
                    font.pixelSize: 26
                    color: Theme.text
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    text: Catalog.platform === "spotify" && !Spotify.connected
                        ? "Подключи Spotify в настройках → Аккаунты: здесь будут твои плейлисты, а поиск заработает."
                        : Catalog.platform === "youtube"
                        ? "Артист, клип или вставь ссылку. Площадку меняет значок слева в нижней панели."
                        : "Артист, альбом или трек. Здесь будет твоя библиотека, когда подключишь аккаунт в настройках → Аккаунты. Площадку меняет значок слева в нижней панели."
                    font.family: Theme.font
                    font.pixelSize: 13
                    lineHeight: 1.3
                    color: Theme.textSecondary
                }
            }
        }

        // ---- The queue, sliding in on the right
        Item {
            x: panel.width - panel.pad - panel.queueW
            y: panel.pad
            width: panel.queueW
            height: content.height
            visible: width > 20 && content.visible
            clip: true
            Rectangle {
                x: -9
                width: 1
                height: parent.height
                color: Theme.hairline
            }
            SectionTitle { id: qTitle; text: "Очередь" }
            QueueList {
                anchors.top: qTitle.bottom
                anchors.topMargin: 10
                anchors.bottom: parent.bottom
                width: parent.width
                onAddRequested: input.forceActiveFocus()
            }
        }

        // ---- Field (closed: the whole bar)
        Item {
            id: footer
            x: panel.pad
            width: panel.width - panel.pad * 2
            height: 44
            y: panel.height - panel.pad - height

            Rectangle {
                id: field
                anchors.left: parent.left
                anchors.right: root.open ? queueBtn.left : parent.right
                anchors.rightMargin: root.open ? 10 : 8
                height: 44
                radius: 22
                color: root.open ? Qt.rgba(0, 0, 0, 0.28) : "transparent"
                border.width: root.open ? (input.activeFocus ? 2 : 1) : 0
                border.color: input.activeFocus ? Qt.rgba(Player.sourceColor(Catalog.platform).r, Player.sourceColor(Catalog.platform).g, Player.sourceColor(Catalog.platform).b, 0.8)
                                                : Theme.hairline

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
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.right: root.open || !countBubble.visible ? busyDot.left : countBubble.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.font
                    font.pixelSize: root.open ? 15 : 14
                    color: Theme.text
                    selectionColor: Player.accent
                    selectedTextColor: "black"
                    clip: true
                    onTextChanged: if (root.open) debounce.restart()
                    Keys.onEscapePressed: root.back()
                    Keys.onReturnPressed: { debounce.stop(); Catalog.run(text); }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !input.text
                        text: root.open ? "Артист, альбом или трек в " + Catalog.platformName(Catalog.platform) + " — или вставь ссылку"
                            : Queue.items.length > 0 ? "Далее: " + Queue.items[0].title + (Queue.items[0].artist ? " — " + Queue.items[0].artist : "")
                            : "Поиск в " + Catalog.platformName(Catalog.platform)
                        font: input.font
                        color: !root.open && Queue.items.length > 0 ? Theme.textSecondary : Theme.textTertiary
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }
                Rectangle {
                    id: busyDot
                    anchors.right: parent.right
                    anchors.rightMargin: root.open ? 18 : 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    radius: 4
                    color: Player.sourceColor(Catalog.platform)
                    opacity: root.open && root.busy ? 1 : 0
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: root.open && root.busy
                        NumberAnimation { to: 0.2; duration: 450 }
                        NumberAnimation { to: 1; duration: 450 }
                    }
                }
                // Closed: how many tracks wait in the queue.
                Rectangle {
                    id: countBubble
                    anchors.right: parent.right
                    anchors.rightMargin: 2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.open && Queue.items.length > 0
                    width: Math.max(26, bubbleText.implicitWidth + 14)
                    height: 26
                    radius: 13
                    color: Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, 0.35)
                    Text {
                        id: bubbleText
                        anchors.centerIn: parent
                        text: Queue.items.length
                        font.family: Theme.font
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                        color: Theme.text
                    }
                }
                // Closed: the bar opens the search.
                MouseArea {
                    anchors.fill: parent
                    visible: !root.open
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.show("")
                }
                Timer {
                    id: debounce
                    interval: 550
                    onTriggered: if (input.text.trim() !== Catalog.query) Catalog.run(input.text)
                }
            }

            Rectangle {
                id: queueBtn
                visible: root.open
                anchors.right: closeBtn.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                height: 44
                width: qRow.implicitWidth + 28
                radius: 22
                color: root.showQueue ? Qt.rgba(1, 1, 1, 0.2) : qArea.containsMouse ? Theme.hover : Qt.rgba(0, 0, 0, 0.2)
                border.width: 1
                border.color: root.showQueue ? Qt.rgba(1, 1, 1, 0.3) : Theme.hairline
                Row {
                    id: qRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; kind: "queue"; size: 18; color: Theme.text }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Очередь"
                        font.family: Theme.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Queue.items.length > 0
                        width: Math.max(22, qCount.implicitWidth + 12)
                        height: 22
                        radius: 11
                        color: Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, 0.5)
                        Text {
                            id: qCount
                            anchors.centerIn: parent
                            text: Queue.items.length
                            font.family: Theme.font
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                    }
                }
                MouseArea {
                    id: qArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showQueue = !root.showQueue
                }
            }

            IconButton {
                id: closeBtn
                visible: root.open
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                size: 44
                tooltip: "Закрыть (Esc)"
                onClicked: root.hide()
            }
        }
    }
}
