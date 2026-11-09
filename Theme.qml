pragma Singleton
import QtQuick
import Quickshell

// Visual tokens (see DESIGN.md). Hues always come from Player's cover palette.
Singleton {
    readonly property string font: "Adwaita Sans"
    // Display face for the centre-stage lyrics (bundled, SIL OFL).
    readonly property string bundledDisplay: displayLoader.status === FontLoader.Ready ? displayLoader.name : "C059"
    // The user's pick from the settings, else the bundled face.
    readonly property string display: Config.lyricsFont || bundledDisplay
    // Menu background colour from the cover tint, at the user's menu opacity.
    function menuColor(alpha) {
        return Qt.rgba(Player.tint.r * 0.6, Player.tint.g * 0.6, Player.tint.b * 0.6, alpha * Config.menuOpacity);
    }

    FontLoader {
        id: displayLoader
        source: Qt.resolvedUrl("fonts/YesevaOne-Regular.ttf")
    }

    readonly property color text: "white"
    readonly property color textSecondary: Qt.rgba(1, 1, 1, 0.66)
    readonly property color textTertiary: Qt.rgba(1, 1, 1, 0.42)
    readonly property color hairline: Qt.rgba(1, 1, 1, 0.10)
    readonly property color hover: Qt.rgba(1, 1, 1, 0.10)
    readonly property color pressed: Qt.rgba(1, 1, 1, 0.18)

    readonly property int coverRadius: 18
    readonly property int slow: 700
    readonly property int quick: 160
}
