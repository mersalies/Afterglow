import QtQuick

// Labelled slider for a numeric setting in [from, to], applied live.
Item {
    id: root

    property string label
    property real from: 0
    property real to: 1
    property real value: 0
    property string unit: ""
    property int decimals: 1
    signal changed(real value)

    width: parent ? parent.width : 260
    height: 44

    Text {
        y: 2
        text: root.label
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: Theme.text
    }
    Text {
        y: 2
        anchors.right: parent.right
        text: root.value.toFixed(root.decimals) + root.unit
        font.family: Theme.font
        font.pixelSize: 12
        font.features: { "tnum": 1 }
        color: Theme.textSecondary
    }
    ThinSlider {
        anchors.bottom: parent.bottom
        width: parent.width
        live: true
        value: (root.value - root.from) / (root.to - root.from)
        onMoved: v => root.changed(root.from + v * (root.to - root.from))
    }
}
