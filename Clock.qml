import QtQuick

// Clock with two styles:
//   wide: one line in the accent colour, date underneath (covers view)
//   tall: date above, light digits condensed to 80% width and stretched to about
//         twice their height, set tight like a lock screen (lyrics view)
Item {
    id: root

    property real size: 140
    property bool tall: false
    property date now: new Date()

    readonly property real stretch: tall ? 2.1 : 1
    readonly property real condense: tall ? 0.8 : 1

    // Measured digit box, so the item's edges sit on the glyphs (no empty band
    // under the stretched digits): digitTop is the gap from the text's top to the
    // top of the digits, digitBottom the distance to their bottom.
    FontMetrics { id: fm; font: time.font }
    readonly property real digitBottom: fm.ascent
    readonly property real digitTop: fm.ascent + fm.tightBoundingRect("0123456789").y

    implicitWidth: Math.max(time.implicitWidth * condense, date.implicitWidth)
    implicitHeight: tall ? time.y + digitBottom * stretch
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
    }

    Text {
        id: time
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.tall ? date.implicitHeight + 8 - root.digitTop * root.stretch : 0
        text: Qt.formatTime(root.now, "HH:mm")
        font.family: Theme.font
        font.pixelSize: root.size
        font.weight: Font.Light
        font.letterSpacing: root.tall ? -root.size * 0.045 : -root.size * 0.035
        // Proportional figures when tall: the "1" stays narrow, as on a lock screen.
        font.features: root.tall ? { "tnum": 0 } : { "tnum": 1 }
        color: root.tall ? Qt.tint(Qt.rgba(0.95, 0.95, 0.97, 0.86), Qt.rgba(Player.accent.r, Player.accent.g, Player.accent.b, 0.12))
                         : Qt.lighter(Player.accent, 1.25)
        Behavior on color { ColorAnimation { duration: Theme.slow * 2 } }
        transform: Scale {
            origin.x: time.width / 2
            origin.y: 0
            xScale: root.condense
            yScale: root.stretch
        }
    }
}
