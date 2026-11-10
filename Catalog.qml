pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Search on one platform at a time, shaped for the search panel: the artist the
// query names (with photo and a line about them), their albums and singles, and
// their ten most popular songs; without an artist, matching albums and songs.
// An album opens with its whole track list. A pasted link goes to Search.
//   spotify        Web API (artist top tracks are closed since 2026, so the
//                  ten most popular songs come from a search by artist)
//   youtube-music  catalog.py, the YouTube Music app's endpoints (unofficial)
//   soundcloud     catalog.py through yt-dlp
//   youtube        catalog.py through yt-dlp: videos only
Singleton {
    id: root

    readonly property var platforms: [
        ["youtube-music", "YouTube Music"], ["spotify", "Spotify"], ["soundcloud", "SoundCloud"], ["youtube", "YouTube"]
    ]
    // The service shown on the transport bar's badge: the one picked in its
    // menu, else the one playing (or the default player); when that cannot be
    // searched (Yandex, VK, ...), the last searchable one picked.
    readonly property string platform: {
        const keys = platforms.map(p => p[0]);
        if (keys.includes(Config.source)) return Config.source;
        const shown = Player.hasPlayer ? Player.source : Config.defaultPlayer;
        if (keys.includes(shown)) return shown;
        return keys.includes(Config.searchPlatform) ? Config.searchPlatform : "youtube-music";
    }
    function platformName(key) { return (platforms.find(p => p[0] === key) || [key, key])[1]; }

    property string query: ""
    property bool busy: false
    property var artist: null      // { id, name, image, sub, about }
    property var albums: []        // [{ id, title, sub, art, year, platform, uri }]
    property var tracks: []
    property string message: ""
    readonly property bool isLink: /^https?:\/\//.test(query)

    // The opened album: { id, title, artist, art, sub, about, tracks, loading, platform, uri }
    property var album: null

    readonly property string helper: Quickshell.shellDir + "/catalog.py"
    property int ticket: 0

    function clear() {
        artist = null;
        albums = [];
        tracks = [];
        message = "";
    }

    function run(q) {
        query = (q || "").trim();
        ticket++;
        album = null;
        clear();
        if (job) job.running = false;
        busy = false;
        if (query === "") { Search.run(""); return; }
        if (isLink) { Search.run(query); return; }

        busy = true;
        const t = ticket;
        if (platform === "spotify") spotifySearch(query, t);
        else helperRun(["search", platform, query], t, d => {
            artist = d.artist ?? null;
            albums = d.albums ?? [];
            tracks = d.tracks ?? [];
            if (!artist && !albums.length && !tracks.length) message = "Ничего не нашлось";
        });
    }

    // Search again when the service changes (not under an open album).
    onPlatformChanged: if (query !== "" && !isLink && !album) run(query)

    function openAlbum(a) {
        ticket++;
        const t = ticket;
        album = { id: a.id, title: a.title, artist: a.artist || artist?.name || "", art: a.art, sub: a.sub || "",
                  about: "", tracks: [], loading: true, platform: a.platform, uri: a.uri || "" };
        const done = d => {
            if (t !== ticket || !album) return;
            album = Object.assign({}, album, {
                title: d.title || album.title, artist: d.artist || album.artist, art: d.art || album.art,
                sub: d.sub || album.sub, about: d.about || "", tracks: d.tracks || [], loading: false
            });
        };
        if (a.platform === "spotify") spotifyAlbum(a.id, done);
        else helperRun(["album", a.platform, a.id], t, done);
    }
    function closeAlbum() { album = null; }

    // ---- catalog.py: one process per request, so a cancelled one can never
    // answer for the next (each knows its own ticket).

    property var job: null
    function helperRun(args, t, cb) {
        if (job) job.running = false;
        job = procComp.createObject(root, { ticket: t, cb, command: ["python3", "-I", helper].concat(args) });
        job.running = true;
    }
    function fail(t) {
        if (t !== ticket) return;
        busy = false;
        if (album) album = Object.assign({}, album, { loading: false });
        else if (!tracks.length && !albums.length) message = "Площадка не ответила";
    }
    Component {
        id: procComp
        Process {
            id: p
            property int ticket
            property var cb
            property bool exited: false
            property bool read: false
            function settle() { if (exited && read) { if (root.job === p) root.job = null; p.destroy(); } }
            stdout: StdioCollector {
                onStreamFinished: {
                    p.read = true;
                    if (p.ticket === root.ticket && text.trim() !== "") {
                        let d = null;
                        try { d = JSON.parse(text); } catch (e) {}
                        if (d) { root.busy = false; root.message = ""; p.cb(d); }
                        else root.fail(p.ticket);
                    }
                    p.settle();
                }
            }
            onExited: code => {
                p.exited = true;
                if (code !== 0) root.fail(p.ticket);
                p.settle();
            }
        }
    }

    // ---- Spotify

    function norm(s) { return Lyrics.norm(s); }

    function albumTile(a) {
        const images = a.images ?? [];
        const year = (a.release_date || "").slice(0, 4);
        return {
            id: a.id, title: a.name, art: (images[1] ?? images[0])?.url ?? "", year, uri: a.uri,
            sub: (a.album_type === "single" ? "Сингл" : a.album_type === "compilation" ? "Сборник" : "Альбом") + (year ? " • " + year : ""),
            artist: (a.artists || []).map(x => x.name).join(", "), platform: "spotify"
        };
    }

    function spotifySearch(q, t) {
        if (!Spotify.connected) {
            busy = false;
            message = "Поиск по Spotify работает после подключения: Настройки → Аккаунты.";
            return;
        }
        const enc = encodeURIComponent;
        Spotify.api("GET", "/search?type=artist,album,track&limit=10&q=" + enc(q), null, (code, d) => {
            if (t !== ticket) return;
            if (code !== 200 || !d) { busy = false; message = "Spotify не ответил"; return; }
            const nq = norm(q);
            const a = (d.artists?.items ?? []).find(x => norm(x.name) === nq || (nq.length > 2 && norm(x.name).includes(nq)));
            if (!a) {
                busy = false;
                albums = (d.albums?.items ?? []).filter(x => x).map(albumTile);
                tracks = (d.tracks?.items ?? []).map(Spotify.trackFrom).filter(x => x);
                if (!albums.length && !tracks.length) message = "Ничего не нашлось";
                return;
            }
            const images = a.images ?? [];
            artist = { id: a.id, name: a.name, image: images[0]?.url ?? "", sub: "Spotify", about: "" };
            let left = 2;
            const doneOne = () => { if (--left === 0 && t === ticket) busy = false; };
            Spotify.api("GET", "/artists/" + a.id + "/albums?include_groups=album,single&limit=10", null, (c2, d2) => {
                if (t !== ticket) return;
                albums = c2 === 200 ? (d2?.items ?? []).map(albumTile) : [];
                doneOne();
            });
            Spotify.api("GET", "/search?type=track&limit=10&q=" + enc("artist:\"" + a.name + "\""), null, (c3, d3) => {
                if (t !== ticket) return;
                tracks = c3 === 200 ? (d3?.tracks?.items ?? []).map(Spotify.trackFrom).filter(x => x) : [];
                doneOne();
            });
        });
    }

    function spotifyAlbum(id, done) {
        Spotify.api("GET", "/albums/" + id, null, (code, d) => {
            if (code !== 200 || !d) { done({ tracks: [] }); return; }
            const tile = albumTile(d);
            const items = (d.tracks?.items ?? []).map(x => Spotify.trackFrom(Object.assign({}, x, { album: { name: d.name, images: d.images } })));
            done({ title: d.name, artist: tile.artist, art: (d.images ?? [])[0]?.url ?? tile.art, sub: tile.sub,
                   about: d.label ? "℗ " + d.label : "", tracks: items.filter(x => x) });
        });
    }
}
