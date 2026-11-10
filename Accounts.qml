pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Linked accounts besides Spotify (which has its own sign-in in Spotify.qml):
//   YouTube Music  the browser's sign-in (cookies, see youtubeCookies) gives
//                  your liked songs, and lets yt-dlp past "confirm you're not a bot"
//   SoundCloud     a public profile name gives its liked tracks
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

    // ---- SoundCloud: likes of a public profile

    readonly property string scName: Config.soundcloudUser.trim()
        .replace(/^https?:\/\/(www\.|m\.)?soundcloud\.com\//, "").replace(/\/.*$/, "")

    function loadSc() {
        sc.running = false;
        if (!scName) { scStatus = "off"; scLikes = []; return; }
        scStatus = "checking";
        sc.command = ["yt-dlp", "--no-warnings", "--flat-playlist", "-J", "--playlist-items", "1:300",
                      "https://soundcloud.com/" + scName + "/likes"];
        sc.running = true;
    }
    // The flat list has only links and titles; the artist is the uploader in the
    // link (soundcloud.com/<artist>/<track>). Liked playlists are left out.
    function slugName(slug) {
        return slug.replace(/[-_]+/g, " ").replace(/\b\w/g, c => c.toUpperCase());
    }
    Process {
        id: sc
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                if (!d) return;
                root.scLikes = (d.entries ?? []).filter(e => e?.url && !/\/sets\//.test(e.url)).map(e => {
                    const slug = (e.url.match(/soundcloud\.com\/([^/]+)\//) || [])[1] || "";
                    return {
                        title: e.title || "", artist: slugName(slug), album: "", art: "",
                        uri: e.url, source: "soundcloud", length: e.duration || 0
                    };
                });
                root.scStatus = "ok";
            }
        }
        onExited: code => { if (code !== 0) root.scStatus = "error"; }
    }
}
