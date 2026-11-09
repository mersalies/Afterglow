import QtQuick
import Quickshell

// One-time Spotify setup: the user's own Client ID, then sign-in in the browser.
Flickable {
    id: root

    contentHeight: col.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    component Step: Row {
        property int n
        property alias text: label.text
        width: parent.width
        spacing: 10
        Rectangle {
            width: 22
            height: 22
            radius: 11
            color: Qt.rgba(1, 1, 1, 0.12)
            Text {
                anchors.centerIn: parent
                text: parent.parent.n
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Theme.text
            }
        }
        Text {
            id: label
            width: parent.width - 32
            wrapMode: Text.WordWrap
            textFormat: Text.StyledText
            linkColor: Qt.lighter(Player.accent, 1.3)
            onLinkActivated: url => Qt.openUrlExternally(url)
            font.family: Theme.font
            font.pixelSize: 13
            lineHeight: 1.3
            color: Theme.textSecondary
            HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
        }
    }

    Column {
        id: col
        width: root.width
        spacing: 14

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Подключи Spotify, чтобы выбирать треки из своих плейлистов и видеть очередь."
            font.family: Theme.font
            font.pixelSize: 15
            font.weight: Font.DemiBold
            lineHeight: 1.25
            color: Theme.text
        }

        Step {
            n: 1
            text: 'Создай приложение на <a href="https://developer.spotify.com/dashboard">developer.spotify.com</a>, отметь «Web API».'
        }
        Step {
            n: 2
            text: "Добавь Redirect URI:"
        }

        Rectangle {
            width: parent.width
            height: 36
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.25)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 12
                text: Spotify.redirectUri
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.text
            }
            Text {
                id: copied
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: copyTimer.running ? "Скопировано" : "Копировать"
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: Font.DemiBold
                color: Qt.lighter(Player.accent, 1.3)
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Quickshell.clipboardText = Spotify.redirectUri; copyTimer.restart(); }
                }
            }
            Timer { id: copyTimer; interval: 1500 }
        }

        Step {
            n: 3
            text: "Вставь сюда Client ID приложения:"
        }

        Rectangle {
            width: parent.width
            height: 40
            radius: 10
            color: Qt.rgba(0, 0, 0, 0.25)
            border.width: input.activeFocus ? 2 : 1
            border.color: input.activeFocus ? Player.accent : Theme.hairline

            TextInput {
                id: input
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                verticalAlignment: TextInput.AlignVCenter
                text: Config.spotifyClientId
                font.family: Theme.font
                font.pixelSize: 13
                color: Theme.text
                selectionColor: Player.accent
                selectedTextColor: "black"
                clip: true
                onEditingFinished: Config.spotifyClientId = text.trim()

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !input.text && !input.activeFocus
                    text: "например 1a2b3c4d…"
                    font: input.font
                    color: Theme.textTertiary
                }
            }
        }

        Rectangle {
            id: button
            readonly property bool ready: input.text.trim().length > 10 && Spotify.status !== "signing-in"
            width: parent.width
            height: 42
            radius: 21
            color: ready ? "white" : Qt.rgba(1, 1, 1, 0.12)
            scale: tap.pressed ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: Theme.quick } }

            Text {
                anchors.centerIn: parent
                text: Spotify.status === "signing-in" ? "Жду ответа в браузере…" : "Войти через Spotify"
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
                color: button.ready ? Qt.darker(Player.tint, 1.2) : Theme.textTertiary
            }
            MouseArea {
                id: tap
                anchors.fill: parent
                enabled: button.ready
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Config.spotifyClientId = input.text.trim();
                    Spotify.login();
                }
            }
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            visible: Spotify.status === "error"
            text: Spotify.error
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.3
            color: "#ff8f8f"
        }

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "С 2026 года Spotify пускает такие приложения только с Premium у владельца. Без входа Afterglow всё равно показывает историю и переключает треки в приложении Spotify."
            font.family: Theme.font
            font.pixelSize: 12
            lineHeight: 1.3
            color: Theme.textTertiary
        }
    }
}
