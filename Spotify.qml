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
        cacheFile.setText("{}");
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
    // Spotify limits how often an app may call it, per kind of request. On "429
    // Too Many Requests" that kind of request rests for as long as Spotify asks
    // (Retry-After, remembered across restarts) and answers 429 at once meanwhile,
    // so a blocked endpoint is not hammered further.

    property var blocked: ({})          // { "/me/tracks": until-ms }
    property double limitedUntil: 0     // the latest of them, for messages
    function apiKey(path) {
        return path.replace(/^https:\/\/api\.spotify\.com\/v1/, "").split("?")[0]
            .replace(/\/(playlists|albums|artists|tracks)\/[^/]+/, "/$1/:id");
    }
    function isBlocked(path) { return (blocked[apiKey(path)] ?? 0) > Date.now(); }
    function block(path, seconds) {
        const until = Date.now() + Math.max(30, seconds || 60) * 1000;
        const next = Object.assign({}, blocked);
        next[apiKey(path)] = until;
        blocked = next;
        limitedUntil = Math.max(limitedUntil, until);
        saveCache.restart();
        console.warn("Afterglow: Spotify limited", apiKey(path), "for", Math.round((until - Date.now()) / 60000), "min");
    }
    // When the rest is over, load what could not be loaded.
    Timer {
        running: root.limitedUntil > 0
        interval: 60000
        repeat: true
        onTriggered: if (Date.now() > root.limitedUntil) { root.limitedUntil = 0; root.blocked = {}; if (root.connected) root.loadAll(); }
    }
    readonly property string limitText: limitedUntil > Date.now()
        ? "Spotify временно ограничил запросы, до " + new Date(limitedUntil).toLocaleString(Qt.locale("ru_RU"), "d MMMM HH:mm") : ""

    function api(method, path, body, cb, retried) {
        if (isBlocked(path)) { if (cb) Qt.callLater(() => cb(429, null)); return; }
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 401 && !retried) {
                fetchToken(() => api(method, path, body, cb, true));
                return;
            }
            if (xhr.status === 429) block(path, parseInt(xhr.getResponseHeader("Retry-After")));
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

    // ---- Library cache (~/.cache/afterglow/spotify.json): the library shows at
    // once from disk, and the liked songs (thousands, dozens of requests) are only
    // fetched again when Spotify reports a different count or newest song.

    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/afterglow/spotify.json"
    property bool cacheLoaded: false
    FileView {
        id: cacheFile
        path: root.cachePath
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (root.liked.length === 0) { root.liked = d.liked || []; root.likedTotal = root.liked.length; }
                if (root.playlists.length === 0) root.playlists = d.playlists || [];
                if (root.albums.length === 0) root.albums = d.albums || [];
                if (!root.userId) root.userId = d.userId || "";
                const now = Date.now(), b = {};
                for (const k in (d.blocked || {})) if (d.blocked[k] > now) b[k] = d.blocked[k];
                root.blocked = b;
                root.limitedUntil = Math.max(0, ...Object.values(b));
            } catch (e) {}
            root.cacheLoaded = true;
        }
        onLoadFailed: root.cacheLoaded = true
    }
    Timer {
        id: saveCache
        interval: 2000
        onTriggered: {
            if (!root.connected) return;
            mkCacheDir.running = true;
        }
    }
    Process {
        id: mkCacheDir
        command: ["mkdir", "-p", root.cachePath.replace(/\/[^/]*$/, "")]
        onExited: cacheFile.setText(JSON.stringify({ userId: root.userId, liked: root.liked, playlists: root.playlists,
                                                      albums: root.albums, blocked: root.blocked }))
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
    // Liked songs as one thing to play (the desktop app knows the short form).
    readonly property string likedUri: userId ? "spotify:user:" + userId + ":collection" : "spotify:collection:tracks"
    property int likedTotal: 0

    function loadPlaylists() {
        if (!userId) api("GET", "/me", null, (code, d) => { if (code === 200 && d) { userId = d.id; saveCache.restart(); } });
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
        }, code => { if (code === 200) { playlists = all; saveCache.restart(); } });
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
        }, code => { if (code === 200) { albums = all; saveCache.restart(); } });
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

    // All liked songs (up to 5000), in Spotify's order, newest first. One small
    // request first: same count and same newest song as the cache, nothing to do.
    // A failed load keeps what was there.
    function loadLiked() {
        if (!cacheLoaded) { Qt.callLater(loadLiked); return; }
        api("GET", "/me/tracks?limit=1", null, (code, d) => {
            if (code !== 200 || !d) return;
            const newest = trackFrom(d.items?.[0]?.track)?.uri ?? "";
            if (liked.length && d.total === liked.length && newest === liked[0]?.uri) return;
            const all = [];
            pages("/me/tracks?limit=50", 5000, items => {
                for (const i of items) {
                    const t = trackFrom(i.track);
                    if (t) all.push(t);
                }
                // Nothing cached: show the first page at once, the rest when it is all in.
                if (liked.length === 0) liked = all.slice();
                return items.length;
            }, code => {
                if (code !== 200 && all.length < liked.length) return;
                liked = all;
                likedTotal = all.length;
                saveCache.restart();
            });
        });
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
            openList = { id: "liked", name: "Любимые треки", uri: likedUri, tracks: liked, loading: false,
                         message: liked.length ? "" : (limitText ? limitText + ". Включить их целиком можно кнопками выше." : "Любимых треков нет") };
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
        const t = ++playTicket;
        pickDevice(id => {
            if (t !== playTicket) return;
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
    // Every step checks playTicket: once something else was asked to play (another
    // track, or Afterglow's own player), a late step must not start Spotify.
    property int playTicket: 0
    function cancelPlay() {
        playTicket++;
        waiting = null;
        devicePoll.stop();
    }
    function sendPlay(body, fallbackUri) {
        const t = playTicket;
        const live = () => t === playTicket;
        const send = (dev, retry) => api("PUT", "/me/player/play" + (dev ? "?device_id=" + dev : ""), body, code => {
            if (code >= 200 && code < 300) { refresh.restart(); return; }
            if (!live()) return;
            if (retry) pickDevice(id => { if (live()) id ? send(id, false) : launchAndPlay(body, fallbackUri); });
            else playViaApp(fallbackUri);
        });
        if (appRunning()) send("", true);
        else pickDevice(id => { if (live()) id ? send(id, false) : launchAndPlay(body, fallbackUri); });
    }

    // No Spotify device at all: start the desktop app, wait for it to register
    // as a device (up to ~20 s), then play there.
    property var waiting: null   // { body, uri, tries, ticket }
    function launchAndPlay(body, uri) {
        say("Запускаю Spotify…");
        waiting = { body, uri, tries: 0, ticket: playTicket };
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
                if (!id || root.waiting !== w || w.ticket !== root.playTicket) return;
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
        playTicket++;
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
        running: root.connected && Player.isPlaying && Player.source === "spotify"
        interval: 60000
        repeat: true
        onTriggered: root.loadQueue()
    }
}
