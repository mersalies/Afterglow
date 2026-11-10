import QtQuick

// The one choice of service, from the badge at the left of the transport bar:
// which player Afterglow follows and where the search looks (a magnifier marks
// the service the search uses). The searchable
// services are always listed; Yandex, VK and other players appear while they
// are open. "Automatic" follows whatever plays.
Glass {
    id: root

    property bool open: false
    signal picked

    radius: 18
    width: 290
    height: list.implicitHeight + 12
    // Opaque whatever the menu opacity: the field behind must not show through.
    color: Qt.rgba(Player.tint.r * 0.45, Player.tint.g * 0.45, Player.tint.b * 0.45, 1)

    // Swallow clicks, hover and wheel in the gaps so nothing behind reacts.
    MouseArea { anchors.fill: parent; hoverEnabled: true; onWheel: e => e.accepted = true }

    visible: opacity > 0.01
    opacity: open ? 1 : 0
    scale: open ? 1 : 0.94
    transformOrigin: Item.BottomLeft
    Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property var searchable: Catalog.platforms.map(p => p[0])
    readonly property var entries: {
        const open = Player.sources;
        const out = Catalog.platforms.map(p => {
            const s = open.find(o => o.key === p[0]);
            return { key: p[0], name: p[1], playing: s?.playing ?? false, title: s?.title ?? "", isOpen: !!s };
        });
        for (const s of open)
            if (!out.some(o => o.key === s.key))
                out.push({ key: s.key, name: s.name, playing: s.playing, title: s.title, isOpen: true });
        return out;
    }

    function choose(key) {
        Config.source = key;
        if (searchable.includes(key)) Config.searchPlatform = key;
        picked();
    }

    component Entry: Rectangle {
        id: entry
        property string key
        property string name
        property string sub
        property bool live: false     // its player is playing now
        readonly property bool selected: Config.source === key
        readonly property bool searches: Catalog.platform === key

        width: list.width
        height: 46
        radius: 12
        color: selected ? Qt.rgba(1, 1, 1, 0.12) : mouse.containsMouse ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.quick } }

        Item {
            id: badge
            x: 8
            width: 28
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            PlatformBadge {
                anchors.centerIn: parent
                visible: entry.key !== "auto"
                platform: entry.key
                size: 26
                glow: entry.live
            }
            Rectangle {
                anchors.centerIn: parent
                visible: entry.key === "auto"
                width: 26
                height: 26
                radius: 13
                color: Qt.rgba(1, 1, 1, 0.12)
                Icon { anchors.centerIn: parent; kind: "glow"; size: 16; color: Theme.text }
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: marks.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: entry.name
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: entry.selected ? Font.DemiBold : Font.Normal
                color: Theme.text
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text !== ""
                text: entry.sub
                font.family: Theme.font
                font.pixelSize: 11
                color: entry.live ? Qt.lighter(Player.sourceColor(entry.key), 1.25) : Theme.textTertiary
            }
        }

        Row {
            id: marks
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.searches
                kind: "search"
                size: 14
                color: Theme.textSecondary
            }
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                kind: "check"
                size: 16
                color: Theme.text
                opacity: entry.selected ? 1 : 0
            }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.choose(entry.key)
        }
    }

    Column {
        id: list
        x: 6
        y: 6
        width: parent.width - 12
        spacing: 2

        Repeater {
            model: root.entries
            Entry {
                required property var modelData
                key: modelData.key
                name: modelData.name
                live: modelData.playing
                sub: modelData.playing ? "Играет: " + modelData.title
                    : modelData.isOpen ? (modelData.title || "Открыт")
                    : root.searchable.includes(modelData.key) ? "Поиск и очередь" : ""
            }
        }

        Rectangle {
            width: parent.width - 16
            x: 8
            height: 1
            color: Theme.hairline
        }

        Entry {
            key: "auto"
            name: "Автоматически"
            sub: "То, что играет сейчас"
        }
    }
}
