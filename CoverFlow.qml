import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Cover carousel: what played before on the left (history, each track once), the
// playing track in the middle, what plays next on the right (Afterglow's queue,
// or Spotify's own queue when ours is empty). Scroll or drag to browse;
// click a side card to play it. Drifts back to the current track when idle.
Item {
    id: flow

    readonly property bool isCurrentTrack: Player.hasPlayer && Player.title !== ""
    readonly property var past: History.tracks
        .filter(t => !(t.title === Player.title && t.artist === Player.artist))
        .slice(0, 6).reverse()
    readonly property bool ownQueue: Queue.items.length > 0
    readonly property var upcoming: ownQueue ? Queue.items.slice(0, 6)
        : Spotify.connected && Player.source === "spotify" ? Spotify.queue.slice(0, 6) : []
    readonly property var current: isCurrentTrack ? {
        title: Player.title, artist: Player.artist, album: Player.album,
        art: Player.localArt || Player.artUrl, uri: Player.trackUri, now: true
    } : null
    readonly property var items: past.concat(current ? [current] : [], upcoming)
    readonly property int home: current ? past.length : past.length - 1

    property int target: home
    property real pos: home
    Behavior on pos { SpringAnimation { spring: 2.6; damping: 0.32; epsilon: 0.001 } }
    onTargetChanged: pos = target
    onHomeChanged: { target = home; idle.stop(); }

    // Bare (the stage view): square covers without captions, the side ones turned
    // away steeply and packed close, as on a shelf.
    property bool bare: false
    readonly property real cardSize: bare ? Math.min(height * 0.86, width * 0.3, 420)
                                          : Math.min(height / 1.24 * 0.92, width * 0.32, 460)

    function go(delta) {
        target = Math.max(0, Math.min(items.length - 1, target + delta));
        idle.restart();
    }

    Timer {
        id: idle
        interval: 6000
        onTriggered: flow.target = flow.home
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => {
            const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y;
            if (Math.abs(d) >= 60) flow.go(d > 0 ? -1 : 1);
        }
    }

    DragHandler {
        id: drag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        property int startTarget
        onActiveChanged: if (active) startTarget = flow.target
        onTranslationChanged: {
            const steps = Math.round(-translation.x / (flow.cardSize * 0.45));
            flow.target = Math.max(0, Math.min(flow.items.length - 1, startTarget + steps));
            idle.restart();
        }
    }

    Repeater {
        model: flow.items

        delegate: Item {
            id: card
            required property var modelData
            required property int index

            readonly property real off: index - flow.pos
            readonly property real a: Math.abs(off)
            readonly property bool centre: a < 0.5
            readonly property bool isNow: modelData.now === true

            width: flow.cardSize
            height: flow.bare ? flow.cardSize : flow.cardSize * 1.24
            // Cards ride a gentle arc: the centre one highest, the sides dropping and
            // leaning along the curve. It follows the scroll position, so the arc
            // holds while browsing.
            y: flow.bare ? (flow.height - height) / 2
                : (flow.height - height) / 2 - flow.cardSize * 0.05
                  + flow.cardSize * 0.075 * Math.pow(Math.min(a, 3.2), 1.5)
            rotation: flow.bare ? 0 : Math.max(-9, Math.min(9, off * 3))
            x: flow.width / 2 - width / 2
                + Math.sign(off) * (flow.bare ? Math.min(a, 1) * flow.cardSize * 0.74 + Math.max(0, a - 1) * flow.cardSize * 0.3
                                              : Math.min(a, 1) * flow.cardSize * 0.78 + Math.max(0, a - 1) * flow.cardSize * 0.36)
            z: 100 - a * 10
            scale: (flow.bare ? 1 - Math.min(a, 1) * 0.16 - Math.max(0, Math.min(a, 3) - 1) * 0.05 : 1 - Math.min(a, 3) * 0.13)
                   * (hover.hovered && !centre ? 1.03 : 1)
            opacity: a > 3.6 ? 0 : 1 - Math.max(0, a - 2.2) * 0.7
            visible: opacity > 0.01

            Behavior on scale { NumberAnimation { duration: Theme.quick } }

            transform: Rotation {
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis { x: 0; y: 1; z: 0 }
                angle: flow.bare ? Math.max(-58, Math.min(58, -card.off * 58)) : Math.max(-48, Math.min(48, -card.off * 34))
                distanceToPlane: 1400
            }

            property real breath: isNow ? Audio.bass : 0
            Behavior on breath { NumberAnimation { duration: 120 } }

            Item {
                anchors.fill: parent
                scale: 1 + card.breath * 0.025

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.55)
                    shadowBlur: 1
                    shadowVerticalOffset: flow.cardSize * 0.05
                    blurMax: 40
                }

                // The card: a dark glass frame; the cover sits inside it with its own
                // rounded corners, the caption under it (bare: the cover alone).
                ClippingRectangle {
                    id: frame
                    readonly property real pad: flow.bare ? 0 : Math.round(flow.cardSize * 0.04)
                    anchors.fill: parent
                    radius: flow.bare ? 8 : 24
                    color: flow.bare ? "transparent" : Qt.rgba(0.11, 0.11, 0.13, 0.78)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, card.centre ? 0.20 : 0.10)

                    // Soft light from above, as on glass.
                    Rectangle {
                        visible: !flow.bare
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.07) }
                            GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0) }
                        }
                    }

                    ClippingRectangle {
                        id: art
                        x: frame.pad
                        y: frame.pad
                        width: parent.width - frame.pad * 2
                        height: width
                        radius: flow.bare ? 0 : Math.max(10, frame.radius - frame.pad)
                        color: Qt.lighter(Player.tint, 1.6)

                        Icon {
                            anchors.centerIn: parent
                            kind: "music"
                            size: parent.width * 0.28
                            color: Theme.textTertiary
                        }
                        CrossfadeImage {
                            anchors.fill: parent
                            source: card.modelData.art || ""
                            entrance: card.isNow
                            sourceSize: 384
                        }
                    }

                    // Caption under the cover
                    Column {
                        visible: !flow.bare
                        anchors.top: art.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        anchors.topMargin: flow.cardSize * 0.05
                        spacing: 3

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: card.modelData.title || "Без названия"
                            font.family: Theme.font
                            font.pixelSize: Math.max(13, flow.cardSize * 0.06)
                            font.weight: Font.Bold
                            color: Theme.text
                        }
                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: card.modelData.artist || ""
                            font.family: Theme.font
                            font.pixelSize: Math.max(11, flow.cardSize * 0.044)
                            color: Theme.textSecondary
                        }
                    }

                    // Side cards sink into the field.
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, Math.min(0.45, card.a * 0.2))
                    }
                }
            }

            HoverHandler {
                id: hover
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: {
                    if (!card.centre) {
                        flow.target = card.index;
                        idle.restart();
                    } else if (card.isNow) {
                        Player.toggle();
                    } else if (card.index > flow.home && card.modelData.uri) {
                        if (flow.ownQueue) Queue.playAt(card.index - flow.home - 1);
                        else Queue.playNow(card.modelData);
                    } else {
                        History.play(card.modelData);
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 10
        visible: flow.items.length === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            kind: "music"
            size: 44
            color: Theme.textTertiary
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Сейчас ничего не играет"
            font.family: Theme.font
            font.pixelSize: 22
            font.weight: Font.DemiBold
            color: Theme.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(flow.width - 48, 380)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "Включи трек в Spotify, Яндекс Музыке или в браузере, или выбери его в панели слева."
            font.family: Theme.font
            font.pixelSize: 14
            lineHeight: 1.3
            color: Theme.textSecondary
        }
    }
}
