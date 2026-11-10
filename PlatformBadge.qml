import QtQuick
import QtQuick.Shapes

// A music service as a round badge in its colour with a simple white symbol
// (our own drawings, not the services' logos). Keys as in Player.sourceKey,
// plus "apple" and "afterglow".
Item {
    id: root

    property string platform: ""
    property real size: 28
    property bool glow: false      // a soft halo in the brand colour

    implicitWidth: size
    implicitHeight: size

    readonly property color tone: platform === "apple" ? "#fa2d48"
        : platform === "afterglow" ? Player.accent
        : Player.sourceColor(platform)

    readonly property var paths: ({
        "spotify": "M5.2 9.3c4.4-1.4 9.6-1 13.6 1.2l-.9 1.6c-3.6-1.9-8.3-2.3-12.2-1zM6.4 12.9c3.6-1 7.7-.7 10.8 1.1l-.8 1.4c-2.8-1.5-6.4-1.8-9.6-.9zM7.5 16.2c2.8-.7 5.8-.4 8.2.9l-.7 1.2c-2-1.1-4.7-1.4-7.1-.8z",
        "youtube-music": "M12 5a7 7 0 1 1 0 14 7 7 0 0 1 0-14zm0 1.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11zM10.2 9v6l5-3z",
        "youtube": "M9.4 7.6v8.8l7.2-4.4z",
        "soundcloud": "M7.2 16.5h10.3a3.1 3.1 0 0 0 .3-6.2 4.7 4.7 0 0 0-8.9-1.1 3.7 3.7 0 0 0-1.7 7.3zM3.5 12.2h1.2v4.3H3.5zM5.4 11h1.2v5.5H5.4z",
        "apple": "M9 17.5V6.6a1 1 0 0 1 .78-.98l7-1.6A1 1 0 0 1 18 5v10.5a2.4 2.4 0 1 1-1.6-2.3V8.2l-5.8 1.3v8a2.4 2.4 0 1 1-1.6-2.3z",
        "afterglow": "M12 3.5l1.6 4.9a3 3 0 0 0 1.9 1.9l4.9 1.6-4.9 1.6a3 3 0 0 0-1.9 1.9L12 20.3l-1.6-4.9a3 3 0 0 0-1.9-1.9L3.6 11.9l4.9-1.6a3 3 0 0 0 1.9-1.9z"
    })
    readonly property var letters: ({ "yandex": "Я", "vk": "VK" })
    readonly property string key: platform === "spotify-web" ? "spotify" : platform

    Rectangle {
        anchors.centerIn: parent
        visible: root.glow
        width: root.size * 1.7
        height: width
        radius: width / 2
        color: Qt.rgba(root.tone.r, root.tone.g, root.tone.b, 0.28)
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.tone, 1.18) }
            GradientStop { position: 1; color: Qt.darker(root.tone, 1.25) }
        }
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.25)
    }

    Shape {
        visible: root.paths[root.key] !== undefined || root.letters[root.key] === undefined
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.size / 24 * 0.9
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.key === "spotify" ? "#0b0b0b" : "white"
            strokeColor: "transparent"
            PathSvg { path: root.paths[root.key] ?? "M9 17.5V6.6a1 1 0 0 1 .78-.98l9-2A1 1 0 0 1 20 4.6V15.5a2.5 2.5 0 1 1-1.8-2.4V8.3l-7.4 1.65V17.5A2.5 2.5 0 1 1 9 15.1z" }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.letters[root.key] !== undefined
        text: root.letters[root.key] ?? ""
        font.family: Theme.font
        font.pixelSize: root.size * (text.length > 1 ? 0.38 : 0.5)
        font.weight: Font.Black
        color: root.key === "yandex" ? "#1a1400" : "white"
    }
}
