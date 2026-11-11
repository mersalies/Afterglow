pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Resolves a pasted link for the search panel: Spotify track links through the
// Web API, anything else through yt-dlp (single tracks and playlists). Also
// splits "Artist - Title" upload names. Searching by words lives in Catalog.qml.
Singleton {
    id: root

    property string query: ""
    property var link: []
    property bool linkBusy: false
    readonly property bool busy: linkBusy
    readonly property bool isLink: /^https?:\/\//.test(query.trim())

    // One process per link, so an abandoned one cannot answer for the next.
    property var job: null
    function run(q) {
        query = q.trim();
        link = [];
        if (job) job.running = false;
        job = null;
        linkBusy = false;
        if (!isLink) return;

        linkBusy = true;
        const m = query.match(/open\.spotify\.com\/(?:intl-\w+\/)?track\/(\w+)/);
        if (m) {
            const asked = query;
            Spotify.api("GET", "/tracks/" + m[1], null, (code, d) => {
                if (asked !== query) return;
                linkBusy = false;
                const t = code === 200 ? Spotify.trackFrom(d) : null;
                link = t ? [t] : [];
            });
            return;
        }
        job = linkComp.createObject(root, {
            command: ["yt-dlp", "--no-warnings"].concat(Config.ytCookieArgs(), ["--flat-playlist", "-J", query])
        });
        job.running = true;
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

    Component {
        id: linkComp
        Process {
            id: ln
            stdout: StdioCollector {
                onStreamFinished: {
                    if (root.job !== ln) return;
                    const d = root.parse(text);
                    const src = root.sourceOf(root.query);
                    const entries = d?.entries ?? (d ? [d] : []);
                    root.link = entries.map(e => {
                        const t = root.fromEntry(e, src);
                        if (t && !/^https?:/.test(t.uri) && e.id && src.startsWith("youtube")) t.uri = "https://www.youtube.com/watch?v=" + e.id;
                        return t;
                    }).filter(t => t);
                }
            }
            onExited: code => {
                Qt.callLater(ln.destroy);
                if (root.job !== ln) return;
                root.job = null;
                root.linkBusy = false;
                if (code !== 0 && root.link.length === 0) Spotify.say("Эту ссылку открыть не получилось");
            }
        }
    }
}
