import QtQuick

// Afterglow's queue: what plays now (when the queue drives playback), then the
// upcoming tracks with up / down / remove on hover; click a row to play it.
// When the queue is empty and Spotify is playing, Spotify's own "next" follows.
Item {
    id: root

    signal addRequested

    function sourceLabel(t) { return Player.sourceName(t.source, null); }

    ListView {
        id: list
        anchors.fill: parent
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds
        model: Queue.items

        add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 250 } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 250; easing.type: Easing.OutCubic } }
        remove: Transition { NumberAnimation { properties: "opacity"; to: 0; duration: 180 } }

        header: Column {
            width: list.width
            spacing: 4

            Text {
                visible: Queue.active && Queue.current !== null
                text: "Сейчас"
                leftPadding: 8
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textTertiary
            }
            TrackRow {
                visible: Queue.active && Queue.current !== null
                width: parent.width
                title: Queue.current?.title ?? ""
                subtitle: Queue.current ? [Queue.current.artist, root.sourceLabel(Queue.current)].filter(s => s).join("  ·  ") : ""
                art: Queue.current?.art ?? ""
                active: true
            }

            // The queue is parked (the user took over in another player).
            Rectangle {
                visible: !Queue.active && Queue.items.length > 0
                width: parent.width
                height: 40
                radius: 20
                color: resumeArea.containsMouse ? Theme.pressed : Theme.hover
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { anchors.verticalCenter: parent.verticalCenter; kind: "play"; size: 16; color: Theme.text }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Играть очередь"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }
                MouseArea {
                    id: resumeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Queue.resume()
                }
            }

            Item {
                width: parent.width
                height: 26
                visible: Queue.items.length > 0
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    leftPadding: 8
                    text: "Далее · " + Queue.items.length
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: Theme.textTertiary
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Очистить"
                    font.family: Theme.font
                    font.pixelSize: 12
                    color: clearArea.containsMouse ? Theme.text : Theme.textTertiary
                    MouseArea {
                        id: clearArea
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Queue.clear()
                    }
                }
            }
        }

        delegate: TrackRow {
            required property var modelData
            required property int index
            width: ListView.view.width
            title: modelData.title
            subtitle: [modelData.artist, root.sourceLabel(modelData), modelData.auto ? "из любимых" : ""].filter(s => s).join("  ·  ")
            art: modelData.art
            opacity: modelData.auto ? 0.8 : 1
            editable: true
            onClicked: Queue.playAt(index)
            onMovedUp: Queue.move(index, -1)
            onMovedDown: Queue.move(index, 1)
            onRemoved: Queue.remove(index)
        }

        footer: Column {
            width: list.width
            spacing: 2
            topPadding: 8

            // Spotify carries on after (or instead of) our queue.
            Text {
                visible: Queue.items.length === 0 && Spotify.connected && Player.source === "spotify" && Spotify.queue.length > 0
                leftPadding: 8
                text: "Дальше в Spotify"
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.textTertiary
            }
            Repeater {
                model: Queue.items.length === 0 && Spotify.connected && Player.source === "spotify" ? Spotify.queue.slice(0, 10) : []
                TrackRow {
                    required property var modelData
                    width: list.width
                    title: modelData.title
                    subtitle: modelData.artist
                    art: modelData.art
                    opacity: 0.75
                    nextable: true
                    queueable: true
                    onClicked: Queue.playNow(modelData)
                    onQueuedNext: Queue.addNext(modelData)
                    onQueued: Queue.add(modelData)
                }
            }

            Rectangle {
                width: parent.width
                height: 44
                radius: 22
                color: addArea.containsMouse ? Theme.pressed : Theme.hover
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { anchors.verticalCenter: parent.verticalCenter; kind: "search"; size: 16; color: Theme.text }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Найти и добавить треки"
                        font.family: Theme.font
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: Theme.text
                    }
                }
                MouseArea {
                    id: addArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.addRequested()
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        width: parent.width - 32
        visible: Queue.items.length === 0 && !Queue.active && !(Spotify.connected && Player.source === "spotify" && Spotify.queue.length > 0)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        text: "Очередь пуста. Добавь треки из Spotify, YouTube или SoundCloud, и Afterglow сыграет их по порядку."
        font.family: Theme.font
        font.pixelSize: 13
        lineHeight: 1.3
        color: Theme.textSecondary
    }
}
