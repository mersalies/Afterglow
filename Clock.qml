import QtQuick

// Clock with two styles:
//   wide: one line in the accent colour, date underneath (covers view)
//   tall: date above, light digits condensed to 80% width and stretched to about
//         twice their height, set tight like a lock screen (lyrics view)
// The digits are painted by shaders/clockfill.frag: the colour from the cover,
// a chosen colour or a gradient, and an outline of any thickness (Config.clock*).
Item {
    id: root

    property real size: 140
    property bool tall: false
    property date now: new Date()

    readonly property real stretch: tall ? 2.1 : 1
    readonly property real condense: tall ? 0.8 : 1

    // "accent" is the cover's colour; anything else a colour name or #rrggbb.
    function tone(v) { return v === "accent" ? Qt.lighter(Player.accent, 1.25) : (v || "#ffffff"); }
    property color autoColor: tall ? Qt.tint(Qt.rgba(0.95, 0.95, 0.97, 0.86), Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, 0.12))
                                   : Qt.lighter(Player.accent, 1.25)
    Behavior on autoColor { ColorAnimation { duration: Theme.slow * 2 } }
    readonly property color fill1: Config.clockFill === "auto" ? autoColor : tone(Config.clockColor)
    readonly property color fill2: Config.clockFill === "gradient" ? tone(Config.clockColor2) : fill1
    readonly property real line: Math.max(0, Math.min(16, Config.clockOutline))
    readonly property color line1: tone(Config.clockOutlineColor)
    readonly property color line2: Config.clockOutlineGradient ? tone(Config.clockOutlineColor2) : line1

    // Measured digit box, so the item's edges sit on the glyphs (no empty band
    // under the stretched digits): digitTop is the gap from the text's top to the
    // top of the digits, digitBottom the distance to their bottom.
    FontMetrics { id: fm; font: time.font }
    readonly property real digitBottom: fm.ascent
    readonly property real digitTop: fm.ascent + fm.tightBoundingRect("0123456789").y

    readonly property real timeY: tall ? date.implicitHeight + 8 - digitTop * stretch : 0
    implicitWidth: Math.max(time.implicitWidth * condense, date.implicitWidth)
    implicitHeight: tall ? timeY + digitBottom * stretch
                         : time.implicitHeight + 2 + date.implicitHeight
    width: implicitWidth
    height: implicitHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Text {
        id: date
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.tall ? 0 : time.implicitHeight + 2
        text: root.now.toLocaleDateString(Qt.locale("ru_RU"), root.tall ? "ddd, d MMMM" : "dddd, d MMMM")
        font.family: Theme.font
        font.pixelSize: root.tall ? Math.max(12, root.size * 0.1) : Math.max(13, root.size * 0.11)
        font.weight: root.tall ? Font.DemiBold : Font.Medium
        color: Theme.textSecondary
        style: root.line > 0 ? Text.Outline : Text.Normal
        styleColor: Qt.rgba(root.line1.r, root.line1.g, root.line1.b, 0.7)
    }

    // The digits, drawn white (already condensed and stretched) into a layer with
    // room for the outline around them, then painted by the shader.
    Item {
        id: digits
        readonly property real pad: Math.ceil(root.line) + 2
        x: (root.width - time.implicitWidth * root.condense) / 2 - pad
        y: root.timeY - pad
        width: time.implicitWidth * root.condense + pad * 2
        height: time.implicitHeight * root.stretch + pad * 2

        Text {
            id: time
            x: digits.pad
            y: digits.pad
            text: Qt.formatTime(root.now, "HH:mm")
            font.family: Theme.font
            font.pixelSize: root.size
            font.weight: Font.Light
            font.letterSpacing: root.tall ? -root.size * 0.045 : -root.size * 0.035
            // Proportional figures when tall: the "1" stays narrow, as on a lock screen.
            font.features: root.tall ? { "tnum": 0 } : { "tnum": 1 }
            color: "white"
            transform: Scale {
                xScale: root.condense
                yScale: root.stretch
            }
        }

        layer.enabled: true
        layer.smooth: true
        layer.effect: ShaderEffect {
            readonly property vector2d size: Qt.vector2d(digits.width, digits.height)
            readonly property color fill1: root.fill1
            readonly property color fill2: root.fill2
            readonly property color line1: root.line1
            readonly property color line2: root.line2
            readonly property real angle: Config.clockAngle * Math.PI / 180
            readonly property vector2d dir: Qt.vector2d(Math.cos(angle), Math.sin(angle))
            readonly property real lineWidth: root.line
            fragmentShader: Qt.resolvedUrl("shaders/clockfill.frag.qsb")
        }
    }
}
