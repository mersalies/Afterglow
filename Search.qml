pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Search across services for the queue builder: Spotify (Web API, when
// connected), YouTube and SoundCloud (yt-dlp). A pasted link is resolved
// directly: Spotify track links via the API, anything else via yt-dlp
// (single tracks and playlists).
Singleton {
    id: root

    property string query: ""
    property var youtube: []
    property var soundcloud: []
    property var link: []
    readonly property var spotify: Spotify.results
    property bool ytBusy: false
    property bool scBusy: false
    property bool linkBusy: false
    readonly property bool busy: ytBusy || scBusy || linkBusy
    readonly property bool isLink: /^https?:\/\//.test(query.trim())

    function run(q) {
        query = q.trim();
        youtube = [];
        soundcloud = [];
        link = [];
        yt.running = false;
        sc.running = false;
        ln.running = false;
        if (query === "") { Spotify.search(""); return; }

        if (isLink) {
            const m = query.match(/open\.spotify\.com\/(?:intl-\w+\/)?track\/(\w+)/);
            if (m) {
                linkBusy = true;
                Spotify.api("GET", "/tracks/" + m[1], null, (code, d) => {
                    linkBusy = false;
                    const t = code === 200 ? Spotify.trackFrom(d) : null;
                    link = t ? [t] : [];
                });
                return;
            }
            linkBusy = true;
            ln.command = ["yt-dlp", "--no-warnings"].concat(Config.ytCookieArgs(), ["--flat-playlist", "-J", query]);
            ln.running = true;
            return;
        }

        Spotify.search(query);
        ytBusy = true;
        yt.command = ["yt-dlp", "--no-warnings"].concat(Config.ytCookieArgs(), ["--flat-playlist", "-J", "ytsearch12:" + query]);
        yt.running = true;
        scBusy = true;
        sc.command = ["yt-dlp", "--no-warnings", "--flat-playlist", "-J", "scsearch10:" + query];
        sc.running = true;
    }

    // "Artist - Title (Official Video)" → { artist, title }
    function split(raw, uploader) {
        const t = (raw || "").replace(/\s*[\(\[](official|офиц|music video|lyric|audio|video|клип|hd|4k|mv)[^\)\]]*[\)\]]/gi, "").trim();
        const m = t.match(/^(.+?)\s+[-–—]\s+(.+)$/);
        if (m) return { artist: m[1].trim(), title: m[2].trim() };
        return { artist: (uploader || "").replace(/\s*-\s*Topic$/i, "").replace(/VEVO$/i, "").trim(), title: t };
    }

    function fromEntry(e, source) {
        if (!e) return null;
        const url = e.webpage_url || e.url || (source === "youtube" && e.id ? "https://www.youtube.com/watch?v=" + e.id : "");
        if (!url) return null;
        const who = e.artist || e.uploader || e.channel || "";
        const parts = e.track ? { artist: e.artist || who, title: e.track } : split(e.title, who);
        const thumbs = e.thumbnails || [];
        const art = (source === "youtube" && e.id) ? "https://i.ytimg.com/vi/" + e.id + "/hqdefault.jpg"
            : (thumbs[thumbs.length - 1]?.url ?? e.thumbnail ?? "");
        return { title: parts.title, artist: parts.artist, album: "", art, uri: url, source, length: e.duration || 0 };
    }

    function sourceOf(url) {
        if (/music\.youtube/.test(url)) return "youtube-music";
        if (/youtube\.com|youtu\.be/.test(url)) return "youtube";
        if (/soundcloud/.test(url)) return "soundcloud";
        if (/vk\.(com|ru)/.test(url)) return "vk";
        if (/yandex/.test(url)) return "yandex";
        return "web";
    }

    function parse(text) {
        try { return JSON.parse(text); } catch (e) { return null; }
    }

    Process {
        id: yt
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                root.youtube = (d?.entries ?? []).map(e => root.fromEntry(e, "youtube")).filter(t => t);
                root.ytBusy = false;
            }
        }
        onExited: root.ytBusy = false
    }

    Process {
        id: sc
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                root.soundcloud = (d?.entries ?? []).map(e => root.fromEntry(e, "soundcloud")).filter(t => t);
                root.scBusy = false;
            }
        }
        onExited: root.scBusy = false
    }

    Process {
        id: ln
        stdout: StdioCollector {
            onStreamFinished: {
                const d = root.parse(text);
                const src = root.sourceOf(root.query);
                const entries = d?.entries ?? (d ? [d] : []);
                root.link = entries.map(e => {
                    const t = root.fromEntry(e, src);
                    if (t && !/^https?:/.test(t.uri) && e.id && src.startsWith("youtube")) t.uri = "https://www.youtube.com/watch?v=" + e.id;
                    return t;
                }).filter(t => t);
                root.linkBusy = false;
            }
        }
        onExited: code => {
            root.linkBusy = false;
            if (code !== 0 && root.link.length === 0) Spotify.say("Эту ссылку открыть не получилось");
        }
    }
}
