import QtQuick
import QtQuick.Shapes

// A colour setting: quick swatches ("accent" is the cover's colour), and behind
// the rainbow swatch a wheel (hue around, saturation outwards) with three
// lines for red, green and blue. Values are "accent" or "#rrggbb".
Column {
    id: cp

    property string value
    signal picked(string value)
    property bool custom: false

    width: parent ? parent.width : 300
    spacing: 10

    readonly property color col: value === "accent" ? Player.accent : (value || "#ffffff")
    // Greys have no hue: keep the last one so the knob does not jump.
    property real hue: 0
    onColChanged: if (col.hsvSaturation > 0.02 && col.hsvValue > 0.02) hue = col.hsvHue
    Component.onCompleted: if (col.hsvSaturation > 0.02) hue = col.hsvHue

    function hex(c) {
        const h = v => Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16).padStart(2, "0");
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }

    Flow {
        width: parent.width
        spacing: 7
        Repeater {
            model: ["accent", "#ffffff", "#000000", "#ff453a", "#ff9f0a", "#ffd60a", "#30d158", "#0a84ff", "#bf5af2", "custom"]
            Rectangle {
                id: dot
                required property string modelData
                readonly property bool isCustom: modelData === "custom"
                readonly property bool on: isCustom ? cp.custom : cp.value.toLowerCase() === modelData
                width: 26
                height: 26
                radius: 13
                color: isCustom ? "transparent" : modelData === "accent" ? Player.accent : modelData
                border.width: on ? 2 : 1
                border.color: on ? "white" : Qt.rgba(1, 1, 1, 0.25)
                scale: dotArea.containsMouse ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: 120 } }
                Shape {
                    visible: dot.isCustom
                    anchors.fill: parent
                    anchors.margins: 2
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillGradient: ConicalGradient {
                            centerX: 11; centerY: 11; angle: 0
                            GradientStop { position: 0.00; color: "#ff0000" }
                            GradientStop { position: 0.17; color: "#ffff00" }
                            GradientStop { position: 0.33; color: "#00ff00" }
                            GradientStop { position: 0.50; color: "#00ffff" }
                            GradientStop { position: 0.67; color: "#0000ff" }
                            GradientStop { position: 0.83; color: "#ff00ff" }
                            GradientStop { position: 1.00; color: "#ff0000" }
                        }
                        PathAngleArc { centerX: 11; centerY: 11; radiusX: 11; radiusY: 11; startAngle: 0; sweepAngle: 360 }
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    visible: dot.modelData === "accent"
                    kind: "glow"
                    size: 14
                    color: "white"
                }
                MouseArea {
                    id: dotArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (dot.isCustom) cp.custom = !cp.custom;
                        else cp.picked(dot.modelData);
                    }
                }
            }
        }
    }

    Row {
        visible: cp.custom
        width: parent.width
        spacing: 16

        // Hue around, saturation from the middle outwards.
        Item {
            id: wheel
            width: 112
            height: 112
            readonly property real r: width / 2
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.25)
                    strokeWidth: 1
                    fillGradient: ConicalGradient {
                        centerX: wheel.r; centerY: wheel.r; angle: 0
                        GradientStop { position: 0.00; color: "#ff0000" }
                        GradientStop { position: 0.17; color: "#ffff00" }
                        GradientStop { position: 0.33; color: "#00ff00" }
                        GradientStop { position: 0.50; color: "#00ffff" }
                        GradientStop { position: 0.67; color: "#0000ff" }
                        GradientStop { position: 0.83; color: "#ff00ff" }
                        GradientStop { position: 1.00; color: "#ff0000" }
                    }
                    PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: wheel.r; centerY: wheel.r; focalX: wheel.r; focalY: wheel.r
                        centerRadius: wheel.r
                        GradientStop { position: 0; color: "#ffffffff" }
                        GradientStop { position: 1; color: "#00ffffff" }
                    }
                    PathAngleArc { centerX: wheel.r; centerY: wheel.r; radiusX: wheel.r; radiusY: wheel.r; startAngle: 0; sweepAngle: 360 }
                }
            }
            // The knob: where the colour is on the wheel.
            Rectangle {
                readonly property real a: cp.hue * 2 * Math.PI
                readonly property real d: cp.col.hsvSaturation * (wheel.r - 2)
                width: 14
                height: 14
                radius: 7
                x: wheel.r + d * Math.cos(a) - 7
                y: wheel.r - d * Math.sin(a) - 7
                color: cp.col
                border.width: 2
                border.color: "white"
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.CrossCursor
                preventStealing: true
                function pick(mx, my) {
                    const dx = mx - wheel.r, dy = -(my - wheel.r);
                    let h = Math.atan2(dy, dx) / (2 * Math.PI);
                    if (h < 0) h += 1;
                    const s = Math.min(1, Math.hypot(dx, dy) / (wheel.r - 2));
                    cp.hue = h;
                    cp.picked(cp.hex(Qt.hsva(h, s, Math.max(0.25, cp.col.hsvValue), 1)));
                }
                onPressed: e => pick(e.x, e.y)
                onPositionChanged: e => { if (pressed) pick(e.x, e.y); }
            }
        }

        // Red, green, blue.
        Column {
            width: parent.width - wheel.width - 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            Repeater {
                model: [["r", "#ff453a"], ["g", "#30d158"], ["b", "#0a84ff"]]
                Row {
                    id: line
                    required property var modelData
                    width: parent.width
                    spacing: 8
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: line.modelData[1]
                    }
                    ThinSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 8 - 30 - 16
                        live: true
                        value: cp.col[line.modelData[0]]
                        onMoved: v => {
                            const c = { r: cp.col.r, g: cp.col.g, b: cp.col.b };
                            c[line.modelData[0]] = v;
                            cp.picked(cp.hex(c));
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignRight
                        text: Math.round(cp.col[line.modelData[0]] * 255)
                        font.family: Theme.font
                        font.pixelSize: 11
                        font.features: { "tnum": 1 }
                        color: Theme.textSecondary
                    }
                }
            }
            Text {
                text: cp.hex(cp.col).toUpperCase()
                font.family: Theme.font
                font.pixelSize: 11
                color: Theme.textTertiary
            }
        }
    }
}
