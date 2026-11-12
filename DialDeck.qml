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
    // Which track stands first; the fan glides to it (pos follows shift).
    property int shift: 0
    onAllChanged: shift = Math.max(0, Math.min(shift, all.length - shown))
    property real pos: shift
    Behavior on pos { SpringAnimation { spring: 3.2; damping: 0.36; epsilon: 0.002 } }
    function turn(by) { shift = Math.max(0, Math.min(Math.max(0, all.length - shown), shift + by)); }
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
    // It also trembles in time: a fast shake whose size is the kick and the bass.
    property real phase: 0
    NumberAnimation on phase { from: 0; to: 2 * Math.PI; duration: 95; loops: Animation.Infinite; running: dial.visible && Player.isPlaying }
    readonly property real tremble: dial.kick * 3.2 + dial.bass * 1.4

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, ring.containsMouse ? 0.4 : 0.22)
            strokeWidth: ring.containsMouse ? 3 : 1.5
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
            strokeWidth: (ring.containsMouse || ring.pressed ? 6 : 3) + dial.bass * 4
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
        x: dial.cx - dial.d / 2 + Math.sin(dial.phase) * dial.tremble
        y: dial.cy - dial.d / 2 + Math.cos(dial.phase * 2) * dial.tremble * 0.6
        rotation: Math.sin(dial.phase) * dial.kick * 1.4
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
    }

    // Seek: a wide band over the ring (from just inside the disc's edge outwards).
    // Click or drag around it; 12 o'clock is the start. Inside it, a click on
    // the disc plays and pauses.
    MouseArea {
        id: ring
        readonly property real outer: dial.ringR + 13
        readonly property real inner: dial.d / 2 - 12
        x: dial.cx - outer
        y: dial.cy - outer
        width: outer * 2
        height: width
        hoverEnabled: true
        property real at: 0
        property bool seeking: false
        cursorShape: Qt.PointingHandCursor
        function dist(mx, my) { return Math.hypot(mx - width / 2, my - height / 2); }
        function set(mx, my) {
            const a = Math.atan2(mx - width / 2, -(my - height / 2));
            at = (a < 0 ? a + 2 * Math.PI : a) / (2 * Math.PI);
        }
        onPressed: e => {
            const r = dist(e.x, e.y);
            if (r > outer) { e.accepted = false; return; }
            seeking = r >= inner && Player.canSeek;
            if (seeking) set(e.x, e.y);
        }
        onPositionChanged: e => { if (pressed && seeking) set(e.x, e.y); }
        onReleased: e => {
            if (seeking) Player.seekTo(at);
            else if (dist(e.x, e.y) < inner) Player.toggle();
            seeking = false;
        }
        onCanceled: seeking = false
    }

    // Volume: an arc at the left of the ring, quiet at the bottom, loud at the top.
    Item {
        id: vol
        visible: Player.volumeSupported
        readonly property real r: dial.ringR + 26
        readonly property real a0: 128      // degrees clockwise from 3 o'clock: lower left
        readonly property real a1: 232      // upper left
        readonly property real shown: volArea.pressed ? volArea.at : Player.volume
        function point(t, rad) {
            const a = (a0 + (a1 - a0) * t) * Math.PI / 180;
            return Qt.point(dial.cx + rad * Math.cos(a), dial.cy + rad * Math.sin(a));
        }
        Shape {
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, 0.25)
                strokeWidth: volArea.containsMouse || volArea.pressed ? 5 : 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: vol.r; radiusY: vol.r; startAngle: vol.a0; sweepAngle: vol.a1 - vol.a0 }
            }
            ShapePath {
                strokeColor: dial.glow
                strokeWidth: volArea.containsMouse || volArea.pressed ? 5 : 3
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: dial.cx; centerY: dial.cy; radiusX: vol.r; radiusY: vol.r; startAngle: vol.a0; sweepAngle: (vol.a1 - vol.a0) * vol.shown }
            }
        }
        Rectangle {
            readonly property point p: vol.point(vol.shown, vol.r)
            width: volArea.containsMouse || volArea.pressed ? 13 : 9
            height: width
            radius: width / 2
            x: p.x - width / 2
            y: p.y - height / 2
            color: "white"
        }
        Icon {
            readonly property point p: vol.point(-0.09, vol.r)
            x: p.x - size / 2; y: p.y - size / 2
            kind: "volume"; size: 13; color: Theme.textTertiary
        }
        Icon {
            readonly property point p: vol.point(1.09, vol.r)
            x: p.x - size / 2; y: p.y - size / 2
            kind: "volume"; size: 17; color: Theme.textSecondary
        }
        MouseArea {
            id: volArea
            x: dial.cx - vol.r - 16
            y: dial.cy - vol.r - 16
            width: vol.r + 16
            height: (vol.r + 16) * 2
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            property real at: 0
            function inBand(mx, my) {
                const r = Math.hypot(mx - width, my - height / 2);
                return r > ring.outer + 2 && r < vol.r + 16;
            }
            function set(mx, my) {
                let a = Math.atan2(my - height / 2, mx - width) * 180 / Math.PI;
                if (a < 0) a += 360;
                at = Math.max(0, Math.min(1, (a - vol.a0) / (vol.a1 - vol.a0)));
                Player.setVolume(at);
            }
            onPressed: e => { if (!inBand(e.x, e.y)) { e.accepted = false; return; } set(e.x, e.y); }
            onPositionChanged: e => { if (pressed) set(e.x, e.y); }
            onWheel: e => Player.setVolume(Player.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))
        }
    }

    // What is around: thumbnails along the ring, names pointing outwards.
    Repeater {
        model: dial.all
        Item {
            id: spoke
            required property var modelData
            required property int index
            // Seven places, -64°..64° around 3 o'clock, top first; the rest wait
            // past the ends and fade in as the fan turns.
            readonly property real place: index - dial.pos
            readonly property real deg: -64 + 128 * place / (dial.shown - 1)
            readonly property real edge: Math.max(0, -place, place - (dial.shown - 1))
            visible: edge < 1.2
            readonly property real rad: deg * Math.PI / 180
            readonly property real r: dial.ringR + 14 + size / 2
            readonly property real size: Math.max(26, dial.d * 0.13)
            x: dial.cx + r * Math.cos(rad)
            y: dial.cy + r * Math.sin(rad)
            rotation: deg
            opacity: (hover.hovered ? 1 : 0.82) * Math.max(0, 1 - edge)
            scale: ((hover.hovered ? 1.12 : 1) + dial.kick * 0.05) * (1 - Math.min(1, edge) * 0.4)

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
