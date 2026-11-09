pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Optional Spotify Web API layer: playlists, liked songs, the real queue, and
// starting playback. Sign-in is handled by spotify-auth.py (PKCE).
// Without a connection everything falls back to MPRIS OpenUri on the desktop app.
Singleton {
    id: root

    readonly property string helper: Quickshell.shellDir + "/spotify-auth.py"
    readonly property string redirectUri: "http://127.0.0.1:8898/callback"

    property string token: ""
    readonly property bool connected: token !== ""
    // "idle" | "signing-in" | "ready" | "error"
    property string status: "idle"
    property string error: ""

    // track: { title, artist, album, art, uri, source }
    property var playlists: []   // [{ id, name, image, count, uri }]
    property var liked: []
    property var queue: []
    property var openList: null  // { id, name, uri, tracks, loading, message }
    property var results: []     // search results
    property string query: ""
    // Short confirmation shown above the transport bar.
    property string notice: ""

    Component.onCompleted: fetchToken(null)

    // ---- Auth

    property var afterToken: null
    function fetchToken(then) {
        afterToken = then;
        tokenProc.running = true;
    }

    Process {
        id: tokenProc
        command: ["python3", root.helper, "token"]
        property string out: ""
        stdout: SplitParser { onRead: line => tokenProc.out = line.trim() }
        onExited: code => {
            if (code === 0 && out) {
                root.token = out;
                root.status = "ready";
                const then = root.afterToken;
                root.afterToken = null;
                if (then) then(); else root.loadAll();
            } else {
                root.token = "";
                root.status = code === 2 ? "idle" : "error";
                if (code !== 2) root.error = "Не удалось обновить вход в Spotify";
            }
            out = "";
        }
    }

    function login() {
        if (!Config.spotifyClientId) return;
        error = "";
        status = "signing-in";
        loginProc.err = "";
        loginProc.running = true;
    }

    Process {
        id: loginProc
        command: ["python3", root.helper, "login", Config.spotifyClientId]
        property string err: ""
        stderr: SplitParser { onRead: line => loginProc.err += (loginProc.err ? "\n" : "") + line }
        onExited: code => {
            if (code === 0) {
                root.fetchToken(null);
            } else {
                root.status = "error";
                root.error = err || "Вход не завершён";
            }
        }
    }

    function logout() {
        logoutProc.running = true;
        token = "";
        status = "idle";
        playlists = [];
        liked = [];
        queue = [];
        openList = null;
    }

    Process {
        id: logoutProc
        command: ["python3", root.helper, "logout"]
    }

    // ---- Web API

    function api(method, path, body, cb, retried) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 401 && !retried) {
                fetchToken(() => api(method, path, body, cb, true));
                return;
            }
            let data = null;
            try { data = xhr.responseText ? JSON.parse(xhr.responseText) : null; } catch (e) {}
            if (cb) cb(xhr.status, data);
        };
        xhr.open(method, path.startsWith("http") ? path : "https://api.spotify.com/v1" + path);
        xhr.setRequestHeader("Authorization", "Bearer " + token);
        if (body) {
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(body));
        } else {
            xhr.send();
        }
    }

    function trackFrom(t) {
        if (!t) return null;
        const images = t.album?.images ?? t.images ?? [];
        return {
            title: t.name || "",
            artist: t.artists ? t.artists.map(a => a.name).join(", ") : (t.show?.name ?? ""),
            album: t.album?.name ?? "",
            art: (images[1] ?? images[0])?.url ?? "",
            uri: t.uri || "",
            length: (t.duration_ms || 0) / 1000,
            source: "spotify"
        };
    }

    function loadAll() {
        loadPlaylists();
        loadAlbums();
        loadLiked();
        loadQueue();
    }

    // Follows Spotify's `next` links until everything is in (or `max` items).
    function pages(url, max, each, done) {
        let got = 0;
        const step = u => api("GET", u, null, (code, d) => {
            if (code !== 200 || !d) { done(code, got); return; }
            got += each(d.items || []);
            if (d.next && got < max) step(d.next);
            else done(200, got);
        });
        step(url);
    }

    property string userId: ""
    property int likedTotal: 0

    function loadPlaylists() {
        api("GET", "/me", null, (code, d) => { if (code === 200 && d) userId = d.id; });
        const all = [];
        pages("/me/playlists?limit=50", 500, items => {
            for (const p of items) {
                if (!p) continue;
                all.push({
                    id: p.id,
                    name: p.name,
                    image: p.images?.[0]?.url ?? "",
                    count: p.items?.total ?? p.tracks?.total ?? 0,
                    uri: p.uri,
                    owner: p.owner?.id ?? ""
                });
            }
            return items.length;
        }, () => playlists = all);
    }

    // Saved albums.
    property var albums: []   // [{ id, name, artist, image, uri, count }]
    function loadAlbums() {
        const all = [];
        pages("/me/albums?limit=50", 500, items => {
            for (const i of items) {
                const a = i?.album;
                if (!a) continue;
                all.push({ id: a.id, name: a.name, artist: (a.artists || []).map(x => x.name).join(", "),
                           image: a.images?.[1]?.url ?? a.images?.[0]?.url ?? "", uri: a.uri, count: a.total_tracks ?? 0 });
            }
            return items.length;
        }, () => albums = all);
    }

    // Tracks of a playlist, album or the liked songs: cb(tracks) once all pages are in.
    // entry: { kind: "playlist" | "album" | "liked", id, image? }
    function collect(entry, cb) {
        if (entry.kind === "liked") { cb(liked.slice()); return; }
        const all = [];
        if (entry.kind === "album") {
            pages("/albums/" + entry.id + "/tracks?limit=50", 500, items => {
                for (const t of items) {
                    const tr = trackFrom(t);
                    if (tr && tr.uri) { tr.art = tr.art || entry.image || ""; tr.album = entry.name || ""; all.push(tr); }
                }
                return items.length;
            }, () => cb(all));
            return;
        }
        const each = items => {
            for (const i of items) { const t = trackFrom(i?.item ?? i?.track); if (t && t.uri) all.push(t); }
            return items.length;
        };
        pages("/playlists/" + entry.id + "/items?limit=100", 3000, each, code => {
            if (code === 404 && all.length === 0) pages("/playlists/" + entry.id + "/tracks?limit=100", 3000, each, () => cb(all));
            else cb(all);
        });
    }

    // All liked songs (up to 5000), in Spotify's order, newest first.
    function loadLiked() {
        const all = [];
        pages("/me/tracks?limit=50", 5000, items => {
            for (const i of items) {
                const t = trackFrom(i.track);
                if (t) all.push(t);
            }
            // Show the first page at once, the rest when it is all in.
            if (liked.length === 0) liked = all.slice();
            return items.length;
        }, () => { liked = all; likedTotal = all.length; });
    }

    function loadQueue() {
        if (!connected) return;
        api("GET", "/me/player/queue", null, (code, d) => {
            if (code === 200 && d?.queue) {
                // Spotify repeats the playing track and loops short contexts: keep each track once.
                const now = d.currently_playing?.uri ?? Player.trackUri;
                const seen = new Set([now]);
                queue = d.queue.map(trackFrom).filter(t => t && t.uri && !seen.has(t.uri) && seen.add(t.uri)).slice(0, 20);
            }
            else if (code === 204) queue = [];
        });
    }

    function open(pl) {
        if (pl.id === "liked") {
            openList = { id: "liked", name: "Любимые треки", uri: userId ? "spotify:user:" + userId + ":collection" : "",
                         tracks: liked, loading: false, message: "" };
            return;
        }
        openList = { id: pl.id, name: pl.name, uri: pl.uri, tracks: [], loading: true, message: "" };
        const all = [];
        const collect = items => {
            for (const i of items) {
                const t = trackFrom(i?.item ?? i?.track);
                if (t && t.uri) all.push(t);
            }
            if (openList?.id === pl.id && openList.tracks.length === 0 && all.length)
                openList = Object.assign({}, openList, { tracks: all.slice() });
            return items.length;
        };
        const done = code => {
            if (openList?.id !== pl.id) return;
            openList = Object.assign({}, openList, {
                tracks: all,
                loading: false,
                message: all.length ? ""
                    : "Spotify не показывает треки чужих плейлистов (правило с 2026 года). Включить его целиком можно кнопками выше."
            });
        };
        pages("/playlists/" + pl.id + "/items?limit=100", 3000, collect, code => {
            // Older API revision: /tracks
            if (code === 404 && all.length === 0) pages("/playlists/" + pl.id + "/tracks?limit=100", 3000, collect, done);
            else done(code);
        });
    }

    // Play a whole playlist (or liked songs) in Spotify, optionally shuffled.
    // Works for playlists whose tracks the API will not list.
    function playContext(contextUri, shuffle) {
        if (!contextUri) return;
        Queue.release();
        if (!connected) { playViaApp(contextUri); return; }
        pickDevice(id => {
            const dev = id ? "&device_id=" + id : "";
            api("PUT", "/me/player/shuffle?state=" + (shuffle ? "true" : "false") + dev, null,
                () => sendPlay({ context_uri: contextUri }, contextUri));
        });
    }

    // ---- Where to play
    // With the desktop app running, Spotify plays there as usual. Without it,
    // Afterglow uses another Spotify device (e.g. a spotifyd daemon named
    // Config.spotifyDevice), or starts the app and waits for it to come up.

    function appRunning() {
        return Mpris.players.values.some(p => /spotify/i.test(p.dbusName || p.identity || "")
                                             && !/spotifyd/i.test(p.dbusName || ""));
    }

    // cb(deviceId or ""): the active device, else the spotifyd device, else any computer.
    function pickDevice(cb) {
        api("GET", "/me/player/devices", null, (code, d) => {
            const ds = code === 200 ? (d?.devices ?? []) : [];
            const want = (Config.spotifyDevice || "").toLowerCase();
            const dev = ds.find(x => x.is_active)
                ?? (want ? ds.find(x => (x.name || "").toLowerCase() === want) : null)
                ?? ds.find(x => x.type === "Computer");
            cb(dev?.id ?? "");
        });
    }

    // PUT /me/player/play with `body`; without the app, or when Spotify reports no
    // active device, it is retried on a picked device; last resort is the app.
    function sendPlay(body, fallbackUri) {
        const send = (dev, retry) => api("PUT", "/me/player/play" + (dev ? "?device_id=" + dev : ""), body, code => {
            if (code >= 200 && code < 300) { refresh.restart(); return; }
            if (retry) pickDevice(id => id ? send(id, false) : launchAndPlay(body, fallbackUri));
            else playViaApp(fallbackUri);
        });
        if (appRunning()) send("", true);
        else pickDevice(id => id ? send(id, false) : launchAndPlay(body, fallbackUri));
    }

    // No Spotify device at all: start the desktop app, wait for it to register
    // as a device (up to ~20 s), then play there.
    property var waiting: null   // { body, uri, tries }
    function launchAndPlay(body, uri) {
        say("Запускаю Spotify…");
        waiting = { body, uri, tries: 0 };
        launch.running = true;
        devicePoll.restart();
    }
    Process {
        id: launch
        command: ["sh", "-c", "command -v spotify >/dev/null && (setsid spotify >/dev/null 2>&1 &) || xdg-open spotify: >/dev/null 2>&1 &"]
    }
    Timer {
        id: devicePoll
        interval: 1500
        repeat: true
        onTriggered: {
            const w = root.waiting;
            if (!w) { stop(); return; }
            if (++w.tries > 14) { stop(); root.waiting = null; root.say("Spotify не запустился"); return; }
            root.pickDevice(id => {
                if (!id || root.waiting !== w) return;
                devicePoll.stop();
                root.waiting = null;
                root.api("PUT", "/me/player/play?device_id=" + id, w.body, code => {
                    if (code >= 200 && code < 300) refresh.restart();
                    else root.playViaApp(w.uri);
                });
            });
        }
    }

    // Start a track, optionally inside its playlist so "next" continues there.
    function play(uri, contextUri) {
        if (!uri) return;
        if (!connected) { playViaApp(uri); return; }
        sendPlay(contextUri ? { context_uri: contextUri, offset: { uri } } : { uris: [uri] }, uri);
    }

    function playTrack(uri) { play(uri, ""); }

    function addToQueue(t) {
        if (!t?.uri) return;
        if (!connected) { say("Очередь работает после подключения Spotify"); return; }
        api("POST", "/me/player/queue?uri=" + encodeURIComponent(t.uri), null, code => {
            if (code >= 200 && code < 300) {
                say("В очереди: " + t.title);
                refresh.restart();
            } else {
                say(code === 404 ? "Сначала включи что-нибудь в Spotify" : "Spotify не дал добавить трек в очередь");
            }
        });
    }

    function search(q) {
        query = q;
        if (!connected || q.trim() === "") { results = []; return; }
        api("GET", "/search?type=track&limit=10&q=" + encodeURIComponent(q), null, (code, d) => {
            if (q !== query) return;
            results = code === 200 && d?.tracks ? d.tracks.items.map(trackFrom).filter(t => t) : [];
        });
    }

    function say(text) {
        notice = text;
        noticeTimer.restart();
    }

    Timer {
        id: noticeTimer
        interval: 2600
        onTriggered: root.notice = ""
    }

    function playViaApp(uri) {
        const p = Player.playerFor("spotify");
        if (p) p.openUri(uri);
        else {
            say("Нет устройства Spotify: запусти spotifyd или приложение Spotify");
            Qt.openUrlExternally(uri);
        }
    }

    // ---- Keep the queue fresh

    Timer {
        id: refresh
        interval: 1500
        onTriggered: root.loadQueue()
    }

    Connections {
        target: Player
        function onTrackUriChanged() { if (root.connected && Player.source === "spotify") refresh.restart(); }
    }

    Timer {
        running: root.connected && Player.isPlaying
        interval: 30000
        repeat: true
        onTriggered: root.loadQueue()
    }
}
