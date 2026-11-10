import QtQuick
import QtQuick.Effects

// Centre-stage lyrics: the current line, word by word. Without synced lyrics
// (or before the first line) the track title takes the stage instead.
Item {
    id: root

    property real maxFont: 96
    property var stage: null

    // Animation style: the user's pick, or with "auto" a different one for every
    // phrase (never the same twice in a row). `style` is the current phrase's.
    readonly property var styles: ["fly", "extrude", "crumble", "wave", "glitch", "neon", "bounce", "ball"]
    property string style: "fly"
    function pickStyle() {
        if (Config.lyricsStyle !== "auto" && styles.includes(Config.lyricsStyle)) return Config.lyricsStyle;
        const others = styles.filter(x => x !== style);
        return others[Math.floor(Math.random() * others.length)];
    }
    // Picking a style in the menu shows it at once.
    Connections {
        target: Config
        function onLyricsStyleChanged() { root.swap(); }
    }

    readonly property bool lyricsMode: Lyrics.synced && Lyrics.status === "ready" && Lyrics.index >= 0

    // The current lyric line cut into phrases of at most six words (two rows of
    // up to three), each with estimated word times so they follow the singing.
    readonly property int perPhrase: 6
    readonly property var phrases: {
        if (!lyricsMode) return [];
        const i = Lyrics.index;
        const line = Lyrics.lines[i];
        const next = Lyrics.lines[i + 1];
        const words = (line.text || "♪").split(/\s+/).filter(w => w !== "");
        const start = line.time;
        const end = next ? next.time : line.time + 5;
        // Each word gets ~0.22 s + 0.05 s per letter of singing; if that overruns the
        // line, everything is squeezed to 92% of it. Words then light at the pace they
        // are sung, and a pause after the line stays a pause.
        const avail = Math.max(0.6, end - start) * 0.92;
        const need = words.map(w => 0.22 + 0.05 * w.length);
        const sum = need.reduce((a, b) => a + b, 0) || 1;
        const squeeze = Math.min(1, avail / sum);
        let acc = start;
        const times = need.map(d => { const t = acc; acc += d * squeeze; return t; });

        const groups = Math.ceil(words.length / perPhrase);
        const size = Math.ceil(words.length / groups);
        const out = [];
        for (let k = 0; k < words.length; k += size) {
            out.push({ words: words.slice(k, k + size), times: times.slice(k, k + size) });
        }
        out.forEach((ph, k) => {
            ph.start = ph.times[0];
            ph.end = k + 1 < out.length ? out[k + 1].times[0] : end;
        });
        return out;
    }
    readonly property int phraseIndex: {
        let idx = 0;
        for (let k = 1; k < phrases.length; k++) {
            if (Lyrics.now >= phrases[k].start) idx = k;
        }
        return idx;
    }

    readonly property string key: !Player.hasPlayer ? ""
        : lyricsMode ? "L" + Lyrics.index + "." + phraseIndex + "\u0001" + Lyrics.key
        : "T" + Player.title + "\u0001" + Player.artist

    onKeyChanged: swap()
    Component.onCompleted: swap()

    function swap() {
        if (stage) {
            stage.leaving = true;
            stage = null;
        }
        if (key === "") return;

        let props;
        if (lyricsMode) {
            const ph = phrases[phraseIndex];
            props = {
                text: ph.words.join(" "),
                givenTimes: ph.times,
                start: ph.start,
                end: ph.end,
                timed: true
            };
        } else {
            props = { text: Player.title || "♪", timed: false };
        }
        style = pickStyle();
        props.style = style;
        props.maxFont = Qt.binding(() => root.maxFont * (root.lyricsMode ? 1 : 0.8));
        props.width = Qt.binding(() => root.width);
        props.height = Qt.binding(() => root.height);
        const s = stageComp.createObject(stages, props);
        s.gone.connect(() => s.destroy());
        stage = s;
    }

    Component {
        id: stageComp
        LyricStage {}
    }

    // The ball: a lens over the whole stage bulges the stack of words. It follows
    // the current phrase's block and swells a little on kicks.
    Item {
        id: lens
        anchors.fill: parent
        readonly property bool on: root.style === "ball" && root.stage !== null && root.stage.layout.halfW !== undefined
        property real kick: 0
        NumberAnimation on kick { id: lensKick; to: 0; duration: 420; easing.type: Easing.OutCubic; running: false }
        Connections {
            target: Audio
            function onKicked(strength) { lens.kick = Math.min(1, strength); lensKick.restart(); }
        }
        property real ballW: on ? root.stage.layout.halfW * 1.22 + 30 : 200
        property real ballH: on ? root.stage.layout.halfH * 1.12 + 30 : 200
        property real ballY: on ? (root.stage.layout.top + root.stage.layout.bottom) / 2 : height / 2
        Behavior on ballW { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Behavior on ballH { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
        Behavior on ballY { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        layer.enabled: on
        layer.effect: ShaderEffect {
            property size size: Qt.size(lens.width, lens.height)
            property point center: Qt.point(lens.width / 2, lens.ballY)
            property size radius: Qt.size(lens.ballW, lens.ballH)
            property real strength: 0.62 + 0.18 * lens.kick
            fragmentShader: Qt.resolvedUrl("shaders/bulge.frag.qsb")
        }

    Item {
        id: stages
        anchors.fill: parent

        // A drop shadow lifts the words off the backdrop; for neon it becomes a
        // glow in the cover colour that pulses with the bass.
        readonly property bool neon: root.style === "neon"
        property real bass: Audio.bass
        Behavior on bass { NumberAnimation { duration: 110 } }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: stages.neon ? Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, 0.7 + 0.3 * stages.bass)
                                     : Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: stages.neon ? 1.0 : 0.8
            shadowVerticalOffset: stages.neon ? 0 : 4
            shadowScale: stages.neon ? 1.02 + 0.04 * stages.bass : 1
            blurMax: stages.neon ? 48 : 24
        }
    }
    }

    // Artist under the title when the title holds the stage.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.stage ? root.stage.textBottom : parent.height / 2) + 10
        Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        opacity: !root.lyricsMode && Player.hasPlayer ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 400 } }
        text: Player.artist
        font.family: Theme.font
        font.pixelSize: Math.max(15, root.maxFont * 0.22)
        font.weight: Font.Medium
        color: Theme.textSecondary
    }

    Text {
        anchors.centerIn: parent
        visible: !Player.hasPlayer
        text: "Включи музыку"
        font.family: Theme.display
        font.pixelSize: root.maxFont * 0.7
        color: Qt.rgba(1, 1, 1, 0.5)
    }
}
