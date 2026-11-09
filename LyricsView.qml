import QtQuick
import Qt5Compat.GraphicalEffects

// Scrolling lyrics with the active line held at ~38% height.
// Click a line to jump to it.
Item {
    id: root

    property real fontSize: 26

    ListView {
        id: list
        anchors.fill: parent
        visible: Lyrics.status === "ready"
        model: Lyrics.lines
        spacing: root.fontSize * 0.7
        clip: true
        interactive: !Lyrics.synced
        boundsBehavior: Flickable.StopAtBounds
        topMargin: Lyrics.synced ? height * 0.38 : 24
        bottomMargin: Lyrics.synced ? height * 0.55 : 24

        currentIndex: Math.max(0, Lyrics.index)
        highlightRangeMode: Lyrics.synced ? ListView.ApplyRange : ListView.NoHighlightRange
        preferredHighlightBegin: height * 0.38
        preferredHighlightEnd: height * 0.38 + root.fontSize * 2
        highlightMoveDuration: Theme.slow
        highlightMoveVelocity: -1
        onCountChanged: positionViewAtBeginning()

        layer.enabled: true
        layer.effect: OpacityMask { maskSource: fade }

        delegate: Item {
            id: line
            required property var modelData
            required property int index
            readonly property bool current: Lyrics.synced && index === Lyrics.index
            readonly property bool past: Lyrics.synced && index < Lyrics.index

            width: list.width
            height: text.implicitHeight

            KaraokeLine {
                id: text
                width: parent.width
                text: line.modelData.text
                active: line.current || !Lyrics.synced
                progress: !Lyrics.synced ? 1 : line.current ? Lyrics.lineProgress : 0
                fontSize: root.fontSize
                wrap: true
                transformOrigin: Item.TopLeft
                scale: line.current || !Lyrics.synced ? 1 : 0.86
                opacity: !Lyrics.synced || line.current ? 1 : line.past ? 0.55 : 0.8
                Behavior on scale { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutExpo } }
                Behavior on opacity { NumberAnimation { duration: Theme.slow } }
            }

            MouseArea {
                anchors.fill: parent
                enabled: Lyrics.synced && Player.canSeek
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: Player.setPosition(line.modelData.time)
            }
        }
    }

    // Soft fade at the top and bottom of the scroll area.
    Rectangle {
        id: fade
        anchors.fill: list
        visible: false
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.14; color: "black" }
            GradientStop { position: 0.82; color: "black" }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    Column {
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 340)
        spacing: 8
        visible: Lyrics.status !== "ready"

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.family: Theme.font
            font.pixelSize: 17
            font.weight: Font.DemiBold
            color: Theme.textSecondary
            text: Lyrics.status === "loading" ? "Ищу текст…"
                : Lyrics.status === "none" ? "Текста для этого трека не нашлось"
                : "Текст появится, когда заиграет трек"
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: Lyrics.status === "none"
            font.family: Theme.font
            font.pixelSize: 13
            color: Theme.textTertiary
            text: "Тексты берутся из открытой базы LRCLIB, в ней есть не всё."
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: Lyrics.status === "ready" && !Lyrics.synced
        font.family: Theme.font
        font.pixelSize: 12
        color: Theme.textTertiary
        text: "Текст без таймингов"
    }
}
