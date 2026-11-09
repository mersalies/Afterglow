import QtQuick

// A lyric line with a left-to-right fill sweep while it is being sung.
Item {
    id: root

    property string text
    property real progress: 0
    property bool active: false
    property real fontSize: 15
    property bool wrap: false

    implicitHeight: base.implicitHeight
    implicitWidth: base.implicitWidth

    Text {
        id: base
        width: root.width
        text: root.text
        color: "white"
        opacity: 0.42
        font.family: Theme.font
        font.pixelSize: root.fontSize
        font.weight: Font.Bold
        lineHeight: 1.12
        wrapMode: root.wrap ? Text.WordWrap : Text.NoWrap
        elide: root.wrap ? Text.ElideNone : Text.ElideRight
        horizontalAlignment: Text.AlignLeft
    }

    // Single-line text gets a true sweep; wrapped text lights up as a whole.
    Item {
        visible: root.active
        clip: true
        height: base.height
        width: base.lineCount > 1 ? base.width : base.contentWidth * root.progress
        Behavior on width { NumberAnimation { duration: 160 } }

        Text {
            width: base.width
            text: root.text
            color: "white"
            font: base.font
            wrapMode: base.wrapMode
            elide: base.elide
            lineHeight: base.lineHeight
        }
    }
}
