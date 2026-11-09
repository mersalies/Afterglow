import QtQuick
import QtQuick.Effects

// Two-buffer image that crossfades on source change. With `entrance`,
// the incoming image also dissolves out of a blur and settles in scale.
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
        if (source === "") { a.source = ""; b.source = ""; return; }
        const next = front === 0 ? b : a;
        if (next.source == source && next.status === Image.Ready) front = 1 - front;
        else next.source = source;
    }

    function promote(img, idx) {
        if (img.status === Image.Ready && img.source == root.source && front !== idx) front = idx;
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
        onStatusChanged: root.promote(img, idx)
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
