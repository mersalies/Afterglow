import QtQuick
import QtQuick.Shapes
import Quickshell.Widgets

// The playing track as a disc: the cover in a ring that fills as the track
// plays (click the ring to seek), its name and times on the disc, and what
// comes next (or what played before) fanned out along the ring on the right.
Item {
    id: dial

    readonly property real d: Math.max(120, Math.min(height * 0.9, width * 0.4))
    readonly property real cx: width / 2 - d * 0.14
    readonly property real cy: height / 2
    readonly property real ringR: d / 2 + 12
    readonly property color glow: Qt.lighter(Player.accent, 1.2)

    readonly property bool ownQueue: Queue.items.length > 0
    // Everything that can stand around the ring; seven show at a time, the
    // wheel turns the fan through the rest.
    readonly property var all: {
        const next = ownQueue ? Queue.items
            : Spotify.connected && Player.source === "spotify" ? Spotify.queue : [];
        if (next.length) return next.slice(0, 40).map((t, i) => ({ t, kind: ownQueue ? "queue" : "next", i }));
        return History.tracks.filter(t => !(t.title === Player.title && t.artist === Player.artist))
            .slice(0, 40).map((t, i) => ({ t, kind: "past", i }));
    }
    readonly property int shown: 7
    property int shift: 0
    onAllChanged: shift = Math.max(0, Math.min(shift, all.length - shown))
    readonly property var around: all.slice(shift, shift + shown)
    // The fan swings a step as it turns, then settles.
    property real swing: 0
    Behavior on swing { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    function turn(by) {
        const to = Math.max(0, Math.min(all.length - shown, shift + by));
        if (to === shift) return;
        swing = by > 0 ? 18 : -18;
        shift = to;
        Qt.callLater(() => swing = 0);
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: e => { if (Math.abs(e.angleDelta.y) >= 60) dial.turn(e.angleDelta.y > 0 ? -1 : 1); }
    }

    // The beat: the disc swells with the bass, and a kick throws a ring outwards.
    property real kick: 0
    NumberAnimation on kick { id: kickFade; to: 0; duration: 520; easing.type: Easing.OutCubic; running: false }
    Connections {
        target: Audio
        enabled: dial.visible && Player.isPlaying
        function onKicked(strength) { dial.kick = Math.min(1, 0.45 + strength * 0.6); kickFade.restart(); }
    }
    property real bass: Player.isPlaying ? Audio.bass : 0
    Behavior on bass { NumberAnimation { duration: 110 } }

    // Ring: click or drag around it to seek (12 o'clock is the start).
    MouseArea {
        id: ring
        x: dial.cx - dial.ringR - 12
        y: dial.cy - dial.ringR - 12
        width: (dial.ringR + 12) * 2
        height: width
        enabled: Player.canSeek
        property real at: 0
        function set(mx, my) {
            const a = Math.atan2(mx - width / 2, -(my - height / 2));
            at = (a < 0 ? a + 2 * Math.PI : a) / (2 * Math.PI);
        }
        onPressed: e => {
            if (Math.hypot(e.x - width / 2, e.y - height / 2) < dial.d / 2) { e.accepted = false; return; }
            set(e.x, e.y);
        }
        onPositionChanged: e => { if (pressed) set(e.x, e.y); }
        onReleased: Player.seekTo(at)
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.22)
            strokeWidth: 1.5
            fillColor: "transparent"
            PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: dial.ringR; radiusY: dial.ringR; startAngle: 0; sweepAngle: 360 }
        }
        // The ring a kick throws out.
        ShapePath {
            strokeColor: Qt.rgba(dial.glow.r, dial.glow.g, dial.glow.b, dial.kick * 0.7)
            strokeWidth: 2 + dial.kick * 5
            fillColor: "transparent"
            PathAngleArc {
                centerX: dial.cx; centerY: dial.cy
                radiusX: dial.ringR + 4 + (1 - dial.kick) * dial.d * 0.09; radiusY: radiusX
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: dial.glow
            strokeWidth: 3 + dial.bass * 4
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.cx; centerY: dial.cy; radiusX: dial.ringR; radiusY: dial.ringR
                startAngle: -90
                sweepAngle: 360 * (ring.pressed ? ring.at : Player.progress)
            }
        }
    }

    ClippingRectangle {
        id: disc
        x: dial.cx - dial.d / 2
        y: dial.cy - dial.d / 2
        width: dial.d
        height: dial.d
        radius: dial.d / 2
        color: Qt.lighter(Player.tint, 1.6)
        border.width: 3
        border.color: Qt.rgba(1, 1, 1, 0.55)
        scale: 1 + dial.bass * 0.045 + dial.kick * 0.025

        CrossfadeImage {
            anchors.fill: parent
            source: Player.localArt || Player.artUrl
            sourceSize: 512
        }
        // Shade under the words.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.45; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.78) }
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: dial.d * 0.1
            width: dial.d * 0.66
            spacing: 1
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Player.title || "Ничего не играет"
                font.family: Theme.font
                font.pixelSize: Math.max(12, dial.d * 0.055)
                font.weight: Font.Bold
                color: Theme.text
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: Player.artist
                font.family: Theme.font
                font.pixelSize: Math.max(10, dial.d * 0.04)
                color: Theme.textSecondary
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Player.fmt(Player.position) + "   " + (Player.length > 0 ? Player.fmt(Player.length) : "–:––")
                font.family: Theme.font
                font.pixelSize: Math.max(10, dial.d * 0.036)
                font.features: { "tnum": 1 }
                color: Theme.textSecondary
            }
        }
        TapHandler { onTapped: Player.toggle() }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    // What is around: thumbnails along the ring, names pointing outwards.
    Repeater {
        model: dial.around
        Item {
            id: spoke
            required property var modelData
            required property int index
            readonly property int n: dial.around.length
            // -64°..64° around 3 o'clock, top first.
            readonly property real deg: (n <= 1 ? 0 : -64 + 128 * index / (n - 1)) + dial.swing
            readonly property real rad: deg * Math.PI / 180
            readonly property real r: dial.ringR + 14 + size / 2
            readonly property real size: Math.max(26, dial.d * 0.13)
            x: dial.cx + r * Math.cos(rad)
            y: dial.cy + r * Math.sin(rad)
            rotation: deg
            opacity: hover.hovered ? 1 : 0.82
            scale: (hover.hovered ? 1.12 : 1) + dial.kick * 0.05

            ClippingRectangle {
                id: thumb
                x: -spoke.size / 2
                y: -spoke.size / 2
                width: spoke.size
                height: spoke.size
                radius: 7
                color: Qt.rgba(1, 1, 1, 0.12)
                Image {
                    anchors.fill: parent
                    source: spoke.modelData.t.art || ""
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Text {
                id: name
                x: spoke.size / 2 + 8
                anchors.verticalCenter: thumb.verticalCenter
                width: Math.min(implicitWidth, dial.d * 0.55)
                elide: Text.ElideRight
                text: spoke.modelData.t.title || ""
                font.family: Theme.font
                font.pixelSize: Math.max(10, dial.d * 0.04)
                font.weight: Font.DemiBold
                color: Theme.text
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.6)
            }
            // The spoke itself has no size: this is what the pointer hits.
            Item {
                x: -spoke.size / 2
                y: -spoke.size / 2
                width: spoke.size + 8 + name.width
                height: spoke.size
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        const m = spoke.modelData;
                        if (m.kind === "queue") Queue.playAt(m.i);
                        else if (m.kind === "next") Queue.playNow(m.t);
                        else History.play(m.t);
                    }
                }
            }
        }
    }
}
