pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent settings, stored in ~/.config/afterglow/config.json.
// The file is watched, so edits apply live.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/afterglow"

    property alias glowEnabled: adapter.glowEnabled
    property alias glowStrength: adapter.glowStrength
    property alias glowWidth: adapter.glowWidth
    property alias glowWhenPaused: adapter.glowWhenPaused
    property alias glowAboveFullscreen: adapter.glowAboveFullscreen
    property alias glowLine: adapter.glowLine
    property alias glowSpeed: adapter.glowSpeed
    property alias glowReact: adapter.glowReact
    property alias glowSparks: adapter.glowSparks
    property alias glowSparkSize: adapter.glowSparkSize
    property alias glowFollowsWindow: adapter.glowFollowsWindow
    property alias glassOpacity: adapter.glassOpacity
    property alias videoBackground: adapter.videoBackground
    property alias clipOffset: adapter.clipOffset
    property alias lyricsOffset: adapter.lyricsOffset
    property alias autoplayLiked: adapter.autoplayLiked
    property alias youtubeCookies: adapter.youtubeCookies
    property alias lyricsStyle: adapter.lyricsStyle
    property alias lyricsFont: adapter.lyricsFont
    property alias spotifyDevice: adapter.spotifyDevice
    property alias clipCacheMB: adapter.clipCacheMB
    property alias audioCacheMB: adapter.audioCacheMB
    property alias artCacheMB: adapter.artCacheMB
    property alias lyricsScale: adapter.lyricsScale
    property alias centerMode: adapter.centerMode
    property alias cardsShowDelay: adapter.cardsShowDelay
    property alias cardsHideDelay: adapter.cardsHideDelay
    property alias backdropOpacity: adapter.backdropOpacity
    property alias backdropBlur: adapter.backdropBlur
    property alias panelOpacity: adapter.panelOpacity
    property alias menuOpacity: adapter.menuOpacity
    property alias defaultPlayer: adapter.defaultPlayer
    property alias clipQuality: adapter.clipQuality
    property alias soundcloudUser: adapter.soundcloudUser
    property alias searchPlatform: adapter.searchPlatform
    property alias cardsScale: adapter.cardsScale
    property alias volume: adapter.volume
    property alias clockScale: adapter.clockScale
    property alias clockLayer: adapter.clockLayer
    property alias clockFill: adapter.clockFill
    property alias clockColor: adapter.clockColor
    property alias clockColor2: adapter.clockColor2
    property alias clockAngle: adapter.clockAngle
    property alias clockOutline: adapter.clockOutline
    property alias clockOutlineColor: adapter.clockOutlineColor
    property alias clockOutlineColor2: adapter.clockOutlineColor2
    property alias clockOutlineGradient: adapter.clockOutlineGradient
    property alias clockShowLyrics: adapter.clockShowLyrics
    property alias clockShowCovers: adapter.clockShowCovers
    property alias clockShowClip: adapter.clockShowClip
    property alias clockLyricsX: adapter.clockLyricsX
    property alias clockLyricsY: adapter.clockLyricsY
    property alias clockCoversX: adapter.clockCoversX
    property alias clockCoversY: adapter.clockCoversY
    property alias clockClipX: adapter.clockClipX
    property alias clockClipY: adapter.clockClipY

    // The three looks of the window, in the order the mode button steps through.
    readonly property var views: [["lyrics", "Текст"], ["covers", "Обложки"], ["stage", "Сцена"]]
    function viewName(v) { return (views.find(x => x[0] === v) ?? views[0])[1]; }
    function cycleView() {
        view = views[(Math.max(0, views.findIndex(x => x[0] === view)) + 1) % views.length][0];
        Spotify.say("Режим: " + viewName(view));
    }

    function resetClock() {
        clockScale = 1; clockLayer = "back"; clockFill = "auto"; clockColor = "#ffffff"; clockColor2 = "accent";
        clockAngle = 90; clockOutline = 0; clockOutlineColor = "#000000"; clockOutlineColor2 = "accent";
        clockOutlineGradient = false; clockShowLyrics = true; clockShowCovers = true; clockShowClip = true;
        for (const s of ["Lyrics", "Covers", "Clip"]) { root["clock" + s + "X"] = -1; root["clock" + s + "Y"] = -1; }
    }

    // yt-dlp arguments that let YouTube see a signed-in browser (see youtubeCookies).
    function ytCookieArgs() {
        return adapter.youtubeCookies ? ["--cookies-from-browser", adapter.youtubeCookies] : [];
    }
    property alias showLyrics: adapter.showLyrics
    property alias showLibrary: adapter.showLibrary
    property alias view: adapter.view
    property alias source: adapter.source
    property alias spotifyClientId: adapter.spotifyClientId

    FileView {
        id: file
        path: root.dir + "/config.json"
        watchChanges: true
        // Edits from outside are picked up live; our own writes are not re-read
        // (rapid slider changes would otherwise bounce back to older values).
        onFileChanged: if (Date.now() - root.lastSave > 1500) reload()
        onAdapterUpdated: save.restart()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                mkdir.running = true;
            }
        }

        JsonAdapter {
            id: adapter
            property bool glowEnabled: true
            property real glowStrength: 1.0
            property int glowWidth: 110
            property bool glowWhenPaused: false
            property bool glowAboveFullscreen: false
            // Edge light fine-tuning (also in the glow menu in the app):
            property real glowLine: 2.4        // line thickness, px
            property real glowSpeed: 1.0       // how fast colours and streaks travel
            property real glowReact: 1.0       // how hard it reacts to bass and kicks
            property real glowSparks: 1.0      // amount of sparks (0 = none)
            property real glowSparkSize: 1.0   // spark size
            // Only light the monitor that shows the Afterglow window, while its workspace is visible.
            property bool glowFollowsWindow: true
            // How dense the window's glass is: 0 = clear, 1 = solid smoke.
            property real glassOpacity: 0.5
            // Music video from YouTube (yt-dlp) behind the glass, muted.
            property bool videoBackground: true
            // Seconds added to the track position when syncing the clip (intros differ).
            property real clipOffset: 0
            // Seconds added to the playback time for lyrics (+ earlier, - later).
            property real lyricsOffset: 0
            // When the queue runs out, keep playing random liked tracks.
            property bool autoplayLiked: true
            // Browser whose YouTube cookies yt-dlp may use ("firefox", "chromium", ...);
            // empty = none. Needed when YouTube asks to "confirm you're not a bot".
            property string youtubeCookies: ""
            // Centre lyrics animation: "auto" (one per track) or fly, extrude,
            // crumble, wave, glitch, neon, bounce.
            property string lyricsStyle: "auto"
            // Centre lyrics font ("" = the bundled Yeseva One) and size multiplier.
            property string lyricsFont: ""
            // Spotify Connect device to play on when the Spotify app is closed (spotifyd).
            property string spotifyDevice: ""
            // Disk cache limits in MB (~/.cache/afterglow); oldest files go first.
            property int clipCacheMB: 300
            property int audioCacheMB: 300
            property int artCacheMB: 50
            property real lyricsScale: 1.0
            // Centre: "auto" (cards while the mouse moves), "lyrics" or "cards";
            // seconds of movement before cards show / of stillness before lyrics return.
            property string centerMode: "auto"
            property real cardsShowDelay: 0.3
            property real cardsHideDelay: 5
            // Cover / clip backdrop: brightness (0-1) and blur (0-1).
            property real backdropOpacity: 1.0
            property real backdropBlur: 0.1
            // Background opacity of the left panel and of the menus (0-1).
            property real panelOpacity: 1.0
            property real menuOpacity: 1.0
            // Player to show and start when nothing plays ("" = whichever was last).
            property string defaultPlayer: ""
            // Height of the music-video backdrop: 144, 480, 720 or 1080.
            property int clipQuality: 480
            // Public SoundCloud profile (soundcloud.com/<name>) whose likes join the library.
            property string soundcloudUser: ""
            // Where the search looks: spotify, youtube-music, soundcloud, youtube.
            property string searchPlatform: "youtube-music"
            // Size of the cover cards in the centre of the lyrics view (multiplier).
            property real cardsScale: 1.0
            // Volume of Afterglow's own player (YouTube, SoundCloud tracks), 0-1.
            property real volume: 0.8
            // Clock: size multiplier; "back" (under the lyrics and cards) or "front"
            // (over everything but the menus); fill "auto" (from the cover), "solid"
            // or "gradient" (clockColor to clockColor2 at clockAngle degrees, 90 =
            // top to bottom); outline thickness in px (0 = none), its colour, and a
            // second colour when it is a gradient. Colours are "#rrggbb" or "accent"
            // (the cover's colour).
            property real clockScale: 1.0
            property string clockLayer: "back"
            property string clockFill: "auto"
            property string clockColor: "#ffffff"
            property string clockColor2: "accent"
            property real clockAngle: 90
            property real clockOutline: 0
            property string clockOutlineColor: "#000000"
            property string clockOutlineColor2: "accent"
            property bool clockOutlineGradient: false
            // Per scene (lyrics view, covers view, a music video playing): shown or
            // not, and where it was dragged as a share of the free room (-1 = its place).
            property bool clockShowLyrics: true
            property bool clockShowCovers: true
            property bool clockShowClip: true
            property real clockLyricsX: -1
            property real clockLyricsY: -1
            property real clockCoversX: -1
            property real clockCoversY: -1
            property real clockClipX: -1
            property real clockClipY: -1
            property bool showLyrics: true
            property bool showLibrary: true
            // "lyrics" (words on the centre stage), "covers" (carousel with panels) or
            // "stage" (bare carousel and controls straight on the backdrop)
            property string view: "lyrics"
            // "auto" or a source key from Player.sourceKey() ("spotify", "yandex", "youtube-music", ...)
            property string source: "auto"
            // Client ID of the user's own app at developer.spotify.com
            property string spotifyClientId: ""
        }
    }

    property double lastSave: 0
    Timer {
        id: save
        interval: 300
        onTriggered: { root.lastSave = Date.now(); file.writeAdapter(); }
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: file.writeAdapter()
    }
}
