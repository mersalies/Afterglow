pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Linked accounts besides Spotify (which has its own sign-in in Spotify.qml):
//   YouTube Music  the browser's sign-in (cookies, see youtubeCookies) gives
//                  your liked songs, and lets yt-dlp past "confirm you're not a bot"
//   SoundCloud     a public profile name gives its liked tracks and playlists
// Liked tracks join the library in the queue builder and the random autoplay.
// Yandex Music, VK Music and Apple Music have no open API: they play in their
// app or a browser tab, which Afterglow follows over MPRIS.
Singleton {
    id: root

    // "off" | "checking" | "ok" | "error"
    property string ytmStatus: "off"
    property var ytmLiked: []
    property string scStatus: "off"
    property var scLikes: []

    function refresh() {
        loadYtm();
        loadSc();
    }

    // First look a little after start, so it does not compete with the window.
    Timer { running: true; interval: 12000; onTriggered: root.refresh() }

    Timer { id: ytmLater; interval: 900; onTriggered: root.loadYtm() }
    Timer { id: scLater; interval: 1200; onTriggered: root.loadSc() }
    Connections {
        target: Config
        function onYoutubeCookiesChanged() { ytmLater.restart(); }
        function onSoundcloudUserChanged() { scLater.restart(); }
    }

    function parse(text) {
        try { return JSON.parse(text); } catch (e) { return null; }
    }

    // ---- YouTube Music: the "Liked Music" playlist of the signed-in browser

    function loadYtm() {
        ytm.running = false;
        if (!Config.youtubeCookies) { ytmStatus = "off"; ytmLiked = []; return; }
        ytmStatus = "checking";
        ytm.command = ["yt-dlp", "--no-warnings", "--cookies-from-browser", Config.youtubeCookies,
                       "--flat-playlist", "-J", "--playlist-items", "1:500",
                       "https://music.youtube.com/playlist?list=LM"];
        ytm.running = true;
    }
    Process {
        id: ytm
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                if (!d) return;
                root.ytmLiked = (d.entries ?? []).filter(e => e?.id).map(e => {
                    const who = (e.channel || e.uploader || "").replace(/\s*-\s*Topic$/i, "");
                    const parts = Search.split(e.title, who);
                    return {
                        title: parts.title, artist: parts.artist, album: "",
                        art: "https://i.ytimg.com/vi/" + e.id + "/hqdefault.jpg",
                        uri: "https://music.youtube.com/watch?v=" + e.id,
                        source: "youtube-music", length: e.duration || 0
                    };
                });
                root.ytmStatus = "ok";
            }
        }
        onExited: code => { if (code !== 0) root.ytmStatus = "error"; }
    }

    // ---- SoundCloud: likes and playlists of a public profile (catalog.py: its own
    // sets and the sets it liked, then the same again with covers)

    readonly property string scName: Config.soundcloudUser.trim()
        .replace(/^https?:\/\/(www\.|m\.)?soundcloud\.com\//, "").replace(/[\/?#].*$/, "")
    property var scSets: []

    property var scJob: null
    function loadSc() {
        if (scJob) scJob.running = false;
        scJob = null;
        if (!scName) { scStatus = "off"; scLikes = []; scSets = []; return; }
        scStatus = "checking";
        scJob = libComp.createObject(root, { command: ["python3", "-I", Quickshell.shellDir + "/catalog.py", "library", "soundcloud", scName] });
        scJob.running = true;
    }
    Component {
        id: libComp
        Process {
            id: lp
            stdout: SplitParser {
                onRead: line => {
                    const d = root.parse(line);
                    if (!d || root.scJob !== lp) return;
                    root.scLikes = d.tracks ?? [];
                    root.scSets = d.sets ?? [];
                    root.scStatus = "ok";
                }
            }
            onExited: {
                if (root.scJob === lp) {
                    if (root.scStatus === "checking") root.scStatus = "error";
                    root.scJob = null;
                }
                Qt.callLater(lp.destroy);
            }
        }
    }

    // Tracks of a SoundCloud set, one process per request: `cb` gets each fuller
    // answer as it comes ({ more: true } while tracks are still looked up), or
    // null when there was none.
    function scSet(url, cb) {
        const p = setComp.createObject(root, { cb, command: ["python3", "-I", Quickshell.shellDir + "/catalog.py", "album", "soundcloud", url] });
        p.running = true;
    }
    Component {
        id: setComp
        Process {
            id: sp
            property var cb
            property bool got: false
            stdout: SplitParser {
                onRead: line => {
                    const d = root.parse(line);
                    if (!d) return;
                    sp.got = true;
                    sp.cb(d);
                }
            }
            onExited: { if (!sp.got) sp.cb(null); Qt.callLater(sp.destroy); }
        }
    }
}
