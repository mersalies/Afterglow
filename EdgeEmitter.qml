import QtQuick
import QtQuick.Particles

// One edge segment of the glow's sparks: bursts only, thrown into the screen,
// in the colour the edge light shows at this segment.
Emitter {
    required property var glow       // the Glow window (colorAt, colorA)
    required property real at        // perimeter position of this segment's middle
    required property real direction // degrees, pointing into the screen
    property bool ambient: false     // a few slow sparks all the time, besides kick bursts
    property real rate: 1.6
    property real sizeScale: 1.0

    group: glow.colorAt(at) === glow.colorA ? "a" : "b"
    enabled: ambient
    emitRate: rate
    lifeSpan: 1500
    lifeSpanVariation: 400
    size: 13 * sizeScale
    sizeVariation: 6 * sizeScale
    endSize: 3
    velocity: AngleDirection {
        angle: direction
        angleVariation: 28
        magnitude: 50
        magnitudeVariation: 30
    }
}
