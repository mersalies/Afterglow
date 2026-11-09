import QtQuick
import QtQuick.Effects

// One lyric phrase on the centre stage, built from single letters so each style
// can move them on their own. Letters enter, light up white as their word is
// sung (with a small pop), react to the beat, and leave when the next phrase
// takes over. Styles:
//   fly      words fly in out of depth and burst towards the viewer
//   extrude  raised 3D letters, deeper on the bass; explode outwards at the end
//   crumble  letters drop into place one by one; crumble down under gravity
//   wave     letters ride a wave that swells with the bass; jump on kicks
//   glitch   RGB-split letters that twitch on kicks; smear sideways at the end
//   neon     letters flicker on like a sign, glow pulses with the bass
//   bounce   words drop in with a bounce, squash on kicks, fall out
Item {
    id: stage

    property string text
    property real start: 0          // seconds
    property real end: 0            // seconds
    property bool timed: true       // false: every word lit (titles, plain lyrics)
    property var givenTimes: null   // per-word start times; estimated when absent
    property real maxFont: 96
    property bool leaving: false
    property string style: "fly"
    property bool sphere: true      // print the phrase on a bulging sphere

    signal gone

    // ---- Words and their times

    readonly property var words: text.split(/\s+/).filter(w => w !== "")
    readonly property var times: givenTimes ?? (() => {
        const total = words.reduce((n, w) => n + w.length, 0) || 1;
        const dur = Math.max(0.6, Math.min(end - start, 8)) * 0.9;
        let acc = 0;
        return words.map(w => { const t = start + dur * acc / total; acc += w.length; return t; });
    })()

    // ---- Layout: rows of at most three words, as large as the widest row allows.

    FontMetrics { id: fm; font.family: Theme.display; font.pixelSize: 100 }
    readonly property real tracking: 0.04   // em

    readonly property var layout: {
        const maxW = width * 0.86;
        const space = fm.advanceWidth(" ") / 100;
        // Width at 1px, with a little extra tracking so curved letters never touch.
        const unit = words.map(w => fm.advanceWidth(w) / 100 + Math.max(0, Array.from(w).length - 1) * tracking);

        const n = words.length;
        const rowCount = Math.max(1, Math.ceil(n / 3));
        const perRow = Math.ceil(n / rowCount);
        const rows = [];
        for (let k = 0; k < n; k += perRow) {
            const items = [];
            for (let i = k; i < Math.min(n, k + perRow); i++) items.push(i);
            const w = items.reduce((sum, i, j) => sum + unit[i] + (j ? space : 0), 0);
            rows.push({ items, w });
        }

        const widest = Math.max(...rows.map(r => r.w), 0.01);
        const size = Math.max(24, Math.min(maxFont, maxW / widest, height / (rows.length * 1.2)));
        const lineH = size * 1.14;
        const top = (height - rows.length * lineH) / 2;
        const pos = [];
        rows.forEach((r, ri) => {
            let x = (width - r.w * size) / 2;
            for (const i of r.items) {
                pos[i] = { x, y: top + ri * lineH };
                x += (unit[i] + space) * size;
            }
        });
        // Radius of the imaginary sphere the phrase is printed on.
        const radius = Math.max(widest * size / 2, rows.length * lineH / 2);
        return { size, pos, top, bottom: top + rows.length * lineH, radius };
    }
    readonly property real textBottom: layout.bottom

    // Every letter with its word, its index in the word and its resting place.
    readonly property var letters: {
        const out = [];
        const size = layout.size;
        words.forEach((w, wi) => {
            const p = layout.pos[wi];
            if (!p) return;
            let pre = "";
            for (const ch of Array.from(w)) {
                out.push({ ch, wi, x: p.x + (fm.advanceWidth(pre) / 100 + Array.from(pre).length * tracking) * size, y: p.y });
                pre += ch;
            }
        });
        return out;
    }

    function rnd(seed) {
        const s = Math.sin(seed * 12.9898 + text.length * 78.233) * 43758.5453;
        return s - Math.floor(s);
    }

    // ---- Beat

    property real bass: Audio.bass
    Behavior on bass { NumberAnimation { duration: 110 } }
    property real kick: 0
    NumberAnimation on kick { id: kickDecay; to: 0; duration: 380; easing.type: Easing.OutCubic; running: false }
    Connections {
        target: Audio
        function onKicked(strength) {
            stage.kick = Math.min(1, 0.5 + strength * 0.6);
            kickDecay.restart();
        }
    }

    // Free-running clock (seconds) for continuous motion.
    property real t: 0
    NumberAnimation on t { from: 0; to: 3600; duration: 3600000; loops: Animation.Infinite }

    // ---- Per-style timing

    readonly property var enterMs: ({ fly: 700, extrude: 420, crumble: 380, wave: 600, glitch: 320, neon: 900, bounce: 760 })
    readonly property var exitMs: ({ fly: 600, extrude: 950, crumble: 1100, wave: 650, glitch: 420, neon: 650, bounce: 620 })
    readonly property int enterDuration: enterMs[style] ?? 700
    readonly property int exitDuration: exitMs[style] ?? 600
    readonly property int enterEasing: ({ fly: Easing.OutExpo, extrude: Easing.OutBack, crumble: Easing.OutCubic, wave: Easing.OutCubic,
                                          glitch: Easing.Linear, neon: Easing.Linear, bounce: Easing.OutBounce })[style] ?? Easing.OutExpo
    readonly property int exitEasing: ({ fly: Easing.InCubic, extrude: Easing.OutCubic, crumble: Easing.InQuad, wave: Easing.InCubic,
                                         glitch: Easing.InCubic, neon: Easing.Linear, bounce: Easing.InQuad })[style] ?? Easing.InCubic

    function enterDelay(L) {
        switch (style) {
        case "extrude": return 120 + L.index * 22;
        case "crumble": return 120 + L.index * 18;
        case "wave": return 120 + L.index * 25;
        case "glitch": return 100 + Math.abs(L.r1) * 260;
        case "neon": return 80;
        case "bounce": return 140 + L.d.wi * 90;
        default: return 160 + L.d.wi * 60;
        }
    }
    function leaveDelay(L) {
        switch (style) {
        case "crumble": return Math.abs(L.r2) * 350;
        case "wave": return L.index * 14;
        case "bounce": return L.d.wi * 40;
        case "fly": return L.d.wi * 20;
        default: return 0;
        }
    }

    onLeavingChanged: if (leaving) goneTimer.start()
    Timer {
        id: goneTimer
        interval: stage.exitDuration + 450
        onTriggered: stage.gone()
    }

    // ---- The motion of one letter for the current style.
    // i: entry 0→1, o: exit 0→1, k: kick 0..1, b: bass 0..1.
    function effect(L) {
        const i = L.inP, o = L.outP, e = 1 - i, k = kick, b = bass;
        let dx = 0, dy = 0, sc = 1, rot = 0, rx = 0, ry = 0, op = 1, blur = 0;

        switch (style) {
        case "extrude": {
            sc = Math.max(0, i) * (1 + L.pop * 0.12);
            op = Math.min(1, i * 1.5);
            dx = L.r1 * k * 3;
            dy = L.r2 * k * 3;
            if (o > 0) {
                // Explosion: straight out from the phrase's centre, tumbling.
                const cx = L.d.x + L.width / 2 - width / 2;
                const cy = L.d.y + L.height / 2 - (layout.top + layout.bottom) / 2;
                const len = Math.max(1, Math.hypot(cx, cy));
                const speed = 260 + Math.abs(L.r1) * 260;
                dx += (cx / len) * speed * o + L.r2 * 70 * o;
                dy += (cy / len) * speed * o + 160 * o * o;
                rot = L.r3 * 540 * o;
                sc *= 1 + 0.5 * o;
                op *= 1 - o * o;
                blur = o * 0.5;
            }
            break;
        }
        case "crumble": {
            dy = -26 * e;
            op = i;
            dx = L.lit ? 0 : L.r1 * k * 2;
            if (o > 0) {
                dy += (480 + 320 * Math.abs(L.r1)) * o * o;
                dx += L.r2 * 50 * o;
                rot = L.r3 * 160 * o;
                op *= 1 - Math.max(0, o - 0.5) * 2;
            }
            sc = 1 + L.pop * 0.1;
            break;
        }
        case "wave": {
            dy = 30 * e + Math.sin(t * 3.2 + L.index * 0.55) * (3 + b * 16);
            dy -= k * (L.lit ? 16 : 8) * (0.6 + 0.4 * Math.abs(L.r1));
            op = i;
            blur = e * 0.6;
            sc = 1 + L.pop * 0.1;
            if (o > 0) { dy -= 70 * o; op *= 1 - o; blur += o; }
            break;
        }
        case "glitch": {
            dx = i < 1 ? Math.round(L.r1 * 5) * 10 * e : 0;
            dx += Math.round(L.r2 * 2) * k * 8;
            op = i > 0.15 + 0.3 * Math.abs(L.r2) ? 1 : 0.25 * i;
            if (o > 0) { dx += L.r1 * 240 * o; op *= 1 - o; blur = o * 0.8; }
            break;
        }
        case "neon": {
            if (i < 0.98) op = i > Math.abs(L.r1) * 0.85 ? (Math.sin(i * 40 + L.index) > -0.2 ? 1 : 0.2) : 0.04;
            if (o > 0) op = o < Math.abs(L.r2) * 0.8 ? 1 : (Math.sin(o * 50 + L.index) > 0.3 ? 0.5 : 0.03);
            sc = 1 + L.pop * 0.06;
            break;
        }
        case "bounce": {
            dy = -(180 + 60 * Math.abs(L.w1)) * e - k * 6;
            sc = 1 + k * (L.lit ? 0.1 : 0.04) + L.pop * 0.08;
            op = Math.min(1, i * 3);
            if (o > 0) { dy += 320 * o * o; op *= 1 - o; rot = L.w1 * 20 * o; }
            break;
        }
        default: { // fly
            dx = L.w1 * 60 * e;
            dy = (40 + L.w2 * 30) * e;
            sc = 1.45 - 0.45 * i + L.pop * 0.1;
            rx = L.w2 * 55 * e;
            ry = L.w1 * 45 * e;
            op = i;
            blur = e * 1.4;
            if (o > 0) {
                dx += L.w1 * 140 * o;
                dy += -90 * o;
                sc += 0.7 * o;
                rx += -L.w2 * 35 * o;
                ry += L.w1 * 40 * o;
                op *= 1 - o;
                blur += o * 1.4;
            }
        }
        }
        // Sphere: the phrase is printed on a sphere seen from the front. Each letter
        // turns with the surface under it (Y by longitude, X by latitude); the
        // projected spacing shrinks by the same cos() as the turned letters, so they
        // never crowd. Outer rows narrow like a drum, and the middle swells a little.
        if (sphere && layout.radius > 0) {
            const k = 0.7;                                     // curvature
            const R = layout.radius;
            const px = L.d.x + L.width / 2 - width / 2;
            const py = L.d.y + L.height / 2 - (layout.top + layout.bottom) / 2;
            const lon = Math.max(-1.3, Math.min(1.3, px * k / R));
            const lat = Math.max(-1.2, Math.min(1.2, py * k / R));
            const front = Math.cos(lat) * Math.cos(lon);          // 1 at the centre
            const swell = 1 + 0.14 * front;
            const x = R / k * Math.cos(lat) * Math.sin(lon) * swell;
            const y = R / k * Math.sin(lat) * swell;
            dx += x - px;
            dy += y - py;
            sc *= swell * (0.55 + 0.45 * Math.cos(lat));
            ry += lon * 57.3 * 0.75;
            rx += -lat * 57.3 * 0.75;
            op *= 0.5 + 0.5 * front;
        }
        return { dx, dy, sc, rot, rx, ry, op, blur };
    }

    readonly property color dim: Qt.rgba(Qt.lighter(Player.accent, 1.5).r, Qt.lighter(Player.accent, 1.5).g, Qt.lighter(Player.accent, 1.5).b, 0.55)

    // ---- Letters

    Repeater {
        model: stage.letters.length

        delegate: Item {
            id: letter
            required property int index

            readonly property var d: stage.letters[index] ?? { ch: "", wi: 0, x: 0, y: 0 }
            readonly property bool lit: !stage.timed || Lyrics.now >= (stage.times[d.wi] ?? 0)
            // per-letter and per-word randoms in -1..1
            readonly property real r1: stage.rnd(index * 1.7 + 1) * 2 - 1
            readonly property real r2: stage.rnd(index * 2.3 + 5) * 2 - 1
            readonly property real r3: stage.rnd(index * 3.1 + 9) * 2 - 1
            readonly property real w1: stage.rnd(d.wi + 1) * 2 - 1
            readonly property real w2: stage.rnd(d.wi + 7.3) * 2 - 1

            property real inP: 0
            property real outP: 0
            property real pop: 0
            readonly property var fx: stage.effect(letter)

            x: d.x + fx.dx
            y: d.y + fx.dy
            width: glyph.implicitWidth
            height: glyph.implicitHeight
            opacity: Math.max(0, Math.min(1, fx.op))
            scale: fx.sc
            rotation: fx.rot

            transform: [
                Rotation {
                    origin.x: letter.width / 2
                    origin.y: letter.height / 2
                    axis { x: 1; y: 0; z: 0 }
                    angle: letter.fx.rx
                    distanceToPlane: 900
                },
                Rotation {
                    origin.x: letter.width / 2
                    origin.y: letter.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: letter.fx.ry
                    distanceToPlane: 900
                }
            ]

            Component.onCompleted: enter.start()
            SequentialAnimation {
                id: enter
                PauseAnimation { duration: stage.enterDelay(letter) }
                NumberAnimation { target: letter; property: "inP"; to: 1; duration: stage.enterDuration; easing.type: stage.enterEasing }
            }
            SequentialAnimation {
                id: leave
                PauseAnimation { duration: stage.leaveDelay(letter) }
                NumberAnimation { target: letter; property: "outP"; to: 1; duration: stage.exitDuration; easing.type: stage.exitEasing }
            }
            Connections {
                target: stage
                function onLeavingChanged() { if (stage.leaving) { enter.stop(); letter.inP = 1; leave.start(); } }
            }

            onLitChanged: if (lit && stage.timed) popAnim.restart()
            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: letter; property: "pop"; to: 1; duration: 120; easing.type: Easing.OutQuad }
                NumberAnimation { target: letter; property: "pop"; to: 0; duration: 380; easing.type: Easing.OutCubic }
            }

            // Glitch channel split
            readonly property real split: stage.style === "glitch" ? 1.5 + stage.kick * 9 * (0.5 + 0.5 * Math.abs(r1)) : 0

            Item {
                anchors.fill: parent

                layer.enabled: letter.fx.blur > 0.02
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: Math.min(1, letter.fx.blur)
                    blurMax: 32
                    autoPaddingEnabled: true
                }

                // Thin depth for every style, so the letters read as raised.
                Repeater {
                    model: stage.style === "extrude" ? 0 : 3
                    Text {
                        required property int index
                        x: (3 - index) * 0.7
                        y: (3 - index) * 0.9
                        text: letter.d.ch
                        font: glyph.font
                        color: Qt.rgba(0, 0, 0, 0.18 + index * 0.08)
                    }
                }

                // Extrusion: stacked copies behind the face, deeper on the bass.
                Repeater {
                    model: stage.style === "extrude" ? 7 : 0
                    Text {
                        required property int index
                        readonly property real step: 0.8 + stage.bass * 0.7
                        x: (7 - index) * step
                        y: (7 - index) * step * 1.25
                        text: letter.d.ch
                        font: glyph.font
                        color: Qt.darker(Player.accent, 2.6 - index * 0.18)
                    }
                }

                Text {
                    visible: stage.style === "glitch"
                    x: -letter.split
                    text: letter.d.ch
                    font: glyph.font
                    color: Qt.rgba(1, 0.15, 0.45, 0.75)
                }
                Text {
                    visible: stage.style === "glitch"
                    x: letter.split
                    y: letter.split * 0.3
                    text: letter.d.ch
                    font: glyph.font
                    color: Qt.rgba(0.1, 0.9, 1, 0.75)
                }

                Text {
                    id: glyph
                    text: letter.d.ch
                    font.family: Theme.display
                    font.pixelSize: stage.layout.size
                    color: letter.lit ? "white"
                        : stage.style === "extrude" ? Qt.lighter(Player.accent, 1.7)
                        : stage.dim
                    Behavior on color { ColorAnimation { duration: 220 } }
                }
            }
        }
    }
}
