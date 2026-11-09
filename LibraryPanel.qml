import QtQuick

// Left panel: what plays next, what played before, and the Spotify library.
Glass {
    id: root

    // "next" | "history" | "spotify"
    property string tab: "history"
    // No glass sheet: rows float on the field, the playing one raised as a card.
    property bool floating: false

    signal builderRequested

    sheen: !floating
    border.color: floating ? "transparent" : Qt.rgba(1, 1, 1, 0.12)
    clip: false

    readonly property bool hasQueue: Spotify.connected && Player.source === "spotify"
    function isNow(t) { return t.title === Player.title && t.artist === Player.artist; }

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

        readonly property var names: [["next", "Далее"], ["history", "История"], ["spotify", "Spotify"]]
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
            visible: root.tab === "spotify"

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
                    subtitle: modelData.id === "liked" ? "" : modelData.count + " треков"
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
    }
}
