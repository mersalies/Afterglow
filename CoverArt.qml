import QtQuick
import QtQuick.Effects
import Quickshell.Widgets

// Album cover with a tinted drop shadow; breathes with the bass.
Item {
    id: root

    property real radius: Theme.coverRadius
    signal clicked

    property real breath: Audio.bass
    Behavior on breath { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    Item {
        id: card
        anchors.fill: parent
        scale: 1 + root.breath * 0.03

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(Player.tint.r * 0.5, Player.tint.g * 0.5, Player.tint.b * 0.5, 0.75)
            shadowBlur: 1.0
            shadowVerticalOffset: root.height * 0.06
            shadowScale: 0.96
            blurMax: 48
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: root.radius
            color: Qt.lighter(Player.tint, 1.6)

            Icon {
                anchors.centerIn: parent
                kind: "music"
                size: parent.width * 0.3
                color: Theme.textTertiary
                visible: !art.ready
            }

            CrossfadeImage {
                id: art
                anchors.fill: parent
                source: Player.localArt || Player.artUrl
                entrance: true
            }

            // Hairline edge so light covers do not bleed into the field.
            Rectangle {
                anchors.fill: parent
                radius: root.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.08)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
