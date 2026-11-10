import QtQuick
import QtQuick.Effects

// Two-buffer image that crossfades on source change. With `entrance`,
// the incoming image also dissolves out of a blur and settles in scale.
// Each buffer remembers the source string it was given (an url property can
// read back re-encoded and never match), and a download that fails is tried
// again twice.
Item {
    id: root

    property string source
    property bool entrance: false
    property int sourceSize: 600
    property real blurAmount: 0     // permanent blur (backdrop use)
    property real brightness: 0
    property int fillMode: Image.PreserveAspectCrop

    property int front: 0
    readonly property bool ready: (front === 0 ? a : b).status === Image.Ready

    onSourceChanged: {
        // Empty source: drop both buffers (frees the textures).
        if (source === "") { a.load(""); b.load(""); return; }
        const cur = front === 0 ? a : b;
        const next = front === 0 ? b : a;
        if (cur.want === source && cur.status !== Image.Error) return;
        if (next.want === source && next.status === Image.Ready) front = 1 - front;
        else next.load(source);
    }

    function promote(img, idx) {
        if (img.status === Image.Ready && img.want === root.source && front !== idx) front = idx;
    }

    component Layer: Image {
        id: img
        required property int idx
        readonly property bool on: root.front === idx
        anchors.fill: parent
        fillMode: root.fillMode
        sourceSize.width: root.sourceSize
        sourceSize.height: root.sourceSize
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        opacity: on && status === Image.Ready ? 1 : 0
        scale: root.entrance && !on ? 0.94 : 1
        z: on ? 1 : 0
        property string want: ""
        property int tries: 0
        function load(src) { want = src; tries = 0; source = src; }
        onStatusChanged: {
            if (status === Image.Error && want !== "" && tries < 2) { tries++; retry.restart(); return; }
            root.promote(img, idx);
        }
        Timer {
            id: retry
            interval: 1200 * (img.tries)
            onTriggered: { img.source = ""; img.source = img.want; }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
        Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

        property real dissolve: root.entrance && !on ? 1 : 0
        Behavior on dissolve { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }

        layer.enabled: root.blurAmount > 0 || dissolve > 0.01
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: Math.min(1, root.blurAmount + img.dissolve)
            blurMax: root.blurAmount > 0 ? 64 : 32
            saturation: root.blurAmount > 0 ? 0.25 : 0
            brightness: root.brightness
            autoPaddingEnabled: false
        }
    }

    Layer { id: a; idx: 0 }
    Layer { id: b; idx: 1 }
}
