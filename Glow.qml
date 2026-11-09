import QtQuick
import QtQuick.Particles
import Quickshell
import Quickshell.Wayland

// Click-through, full-screen layer: a thin line of light along the screen's
// rounded edge in two cover colours (soft fade where they meet), pulsing with the
// bass, with small sparks thrown inwards from the edge on kicks.
PanelWindow {
    id: win

    required property ShellScreen modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    WlrLayershell.namespace: "afterglow-glow"
    // Above bars and windows, but behind a fullscreen window unless asked otherwise.
    WlrLayershell.layer: Config.glowAboveFullscreen || !AppWindow.fullscreenHere ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    readonly property bool shown: Config.glowEnabled && Player.hasPlayer
        && (Player.isPlaying || Config.glowWhenPaused)
        && AppWindow.glowsOn(modelData)
    visible: shown || light.opacity > 0.01

    // Brightness: 1.0 in the settings is 12% brighter than the original look.
    readonly property real strength: Math.max(0, Math.min(2, Config.glowStrength)) * 1.12
    readonly property real react: Math.max(0, Math.min(2, Config.glowReact))

    property real pulse: Player.isPlaying ? Audio.bass * react : 0
    Behavior on pulse { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // Beat flash: jumps up on a kick, decays.
    property real flash: 0
    NumberAnimation on flash { id: flashDecay; to: 0; duration: 520; easing.type: Easing.OutCubic; running: false }

    // The two-colour split slowly travels around the screen.
    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: 1
        duration: 14000 / Math.max(0.2, Config.glowSpeed)
        loops: Animation.Infinite
        running: win.visible
    }

    readonly property color colorA: Player.accent
    // Keep the two halves apart: if the cover gives two near-identical hues,
    // use a neighbouring hue for the second (analogous pair, like lime and gold).
    readonly property color colorB: {
        const a = Player.accent, b = Player.accent2;
        const d = Math.abs(a.hsvHue - b.hsvHue);
        if (Math.min(d, 1 - d) >= 0.08) return b;
        return Qt.hsva((a.hsvHue + 0.13) % 1, Math.max(0.5, a.hsvSaturation), Math.max(0.8, a.hsvValue), 1);
    }

    // Which colour sits at perimeter position t (same split as the shader).
    function colorAt(t) {
        const s = Math.sin(2 * Math.PI * (((t + phase) % 1 + 1) % 1));
        return s >= 0 ? colorA : colorB;
    }

    Connections {
        target: Audio
        enabled: win.shown
        function onKicked(strength) {
            win.flash = Math.min(0.7, 0.25 + strength * 0.4) * win.react;
            flashDecay.restart();
            const n = Math.round((2 + strength * 5) * Config.glowSparks);
            if (n > 0) for (const e of emitters.children) e.burst(n);
        }
    }

    ShaderEffect {
        id: light
        anchors.fill: parent
        opacity: win.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        property size size: Qt.size(width, height)
        property real radius: 14
        property real inset: 1.5
        property real lineWidth: Math.max(0.8, Config.glowLine)
        property real gain: win.strength
        property real halo: Math.max(8, Config.glowWidth * 0.18)
        property real pulse: win.pulse
        property real flash: win.flash
        property real phase: win.phase
        property color colorA: win.colorA
        property color colorB: win.colorB
        Behavior on colorA { ColorAnimation { duration: 1200 } }
        Behavior on colorB { ColorAnimation { duration: 1200 } }

        fragmentShader: Qt.resolvedUrl("shaders/edge.frag.qsb")
    }

    // ---- Sparks

    ParticleSystem {
        id: sparks
        running: win.visible
    }

    ImageParticle {
        system: sparks
        groups: ["a"]
        source: "qrc:///particleresources/glowdot.png"
        color: win.colorA
        colorVariation: 0.06
        alpha: 1
        alphaVariation: 0.3
        entryEffect: ImageParticle.Fade
        opacity: light.opacity
    }

    ImageParticle {
        system: sparks
        groups: ["b"]
        source: "qrc:///particleresources/glowdot.png"
        color: win.colorB
        colorVariation: 0.06
        alpha: 1
        alphaVariation: 0.3
        entryEffect: ImageParticle.Fade
        opacity: light.opacity
    }

    // Sparks drift and slow down as they leave the edge.
    Wander {
        system: sparks
        xVariance: 30
        yVariance: 30
        pace: 60
    }
    Friction {
        system: sparks
        factor: 1.2
    }

    // Each edge is split in two so a segment's sparks match the colour under it.
    Item {
        id: emitters
        anchors.fill: parent
        readonly property real band: 3

        // t: 0.5 = right middle, 0.75 = bottom middle, 0 = left middle, 0.25 = top middle
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.20; direction: 90;  x: 0; y: 0; width: parent.width / 2; height: emitters.band }
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.30; direction: 90;  x: parent.width / 2; y: 0; width: parent.width / 2; height: emitters.band }
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.45; direction: 180; x: parent.width - emitters.band; y: 0; width: emitters.band; height: parent.height / 2 }
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.55; direction: 180; x: parent.width - emitters.band; y: parent.height / 2; width: emitters.band; height: parent.height / 2 }
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.70; direction: 270; x: parent.width / 2; y: parent.height - emitters.band; width: parent.width / 2; height: emitters.band }
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.80; direction: 270; x: 0; y: parent.height - emitters.band; width: parent.width / 2; height: emitters.band }
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.95; direction: 0;   x: 0; y: parent.height / 2; width: emitters.band; height: parent.height / 2 }
        EdgeEmitter { glow: win; system: sparks; ambient: win.shown && Player.isPlaying && Config.glowSparks > 0; rate: 1.6 * Config.glowSparks; sizeScale: Config.glowSparkSize; at: 0.05; direction: 0;   x: 0; y: 0; width: emitters.band; height: parent.height / 2 }
    }
}
