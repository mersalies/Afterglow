pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Finds a music video for the current track on YouTube (via yt-dlp) and keeps a
// muted copy (480p by default, see clipQuality) in ~/.cache/afterglow/clips for the backdrop. YouTube refuses
// direct playback of its stream URLs outside yt-dlp, so the clip is cached first.
// Only uploads that look like real clips are picked automatically; the user can
// step through other candidates, and the choice per track is remembered.
// With Spotify connected, the next queued track's clip is fetched in advance.
Singleton {
    id: root

    readonly property string key: keyFor(Player.artist, Player.title)
    // "idle" | "searching" | "loading" | "ready" | "none"
    property string status: "idle"
    property var candidates: []     // [{ id, title, duration, score, clip }]
    property int choice: -1
    property string videoId: ""
    property string videoTitle: ""
    property real videoDuration: 0
    property string streamUrl: ""   // file:// URL of the cached clip

    // A clip much longer or shorter than the track cannot follow it: loop it instead.
    readonly property bool synced: videoDuration > 0 && Player.length > 0
        && Math.abs(videoDuration - Player.length) < 25

    readonly property bool enabled: Config.videoBackground
    onEnabledChanged: if (enabled && status === "idle") debounce.restart()

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/afterglow"
    readonly property string clipsDir: cacheDir + "/clips"
    // Video only (the backdrop is muted), no taller than the chosen quality.
    readonly property int quality: [144, 480, 720, 1080].includes(Config.clipQuality) ? Config.clipQuality : 480
    readonly property string format: "bv*[height<=Q][ext=mp4][vcodec^=avc1]/bv*[height<=Q][ext=mp4]/bv*[height<=Q]/bv*".replace(/Q/g, quality)

    function keyFor(artist, title) { return title ? artist + "\u0001" + title : ""; }

    onKeyChanged: {
        status = "idle";
        candidates = [];
        choice = -1;
        videoId = "";
        videoTitle = "";
        videoDuration = 0;
        streamUrl = "";
        cancel();
        debounce.restart();
    }

    Timer {
        id: debounce
        interval: 1200
        onTriggered: root.start()
    }

    function start() {
        if (!enabled || key === "") return;
        const saved = cache.picks[key];
        if (saved?.none) { status = "none"; return; }
        if (saved?.id) { use(saved); return; }
        find(false);
    }

    // ---- Search and ranking

    function cleanTitle(t) {
        return t.replace(/\s*[\(\[].*?[\)\]]/g, "").replace(/\s+-\s+.*$/, "").trim();
    }

    function query(artist, title) {
        return "ytsearch8:" + artist + " " + cleanTitle(title) + " official video";
    }

    function rank(entries, artist, title, length) {
        const want = cleanTitle(title).toLowerCase();
        const who = artist.split(/,|&| feat/i)[0].trim().toLowerCase();
        const bad = /lyric|текст|\baudio\b|альбом|album|slowed|sped up|speed up|reverb|remix|\blive\b|cover|karaoke|караоке|nightcore|\b8d\b|instrumental|минус|reaction|реакция|tiktok|visualizer|snippet/;
        return entries.filter(e => e && e.id).map(e => {
            const t = (e.title || "").toLowerCase();
            const ch = (e.channel || e.uploader || "").toLowerCase();
            let s = 0;
            s += want && t.includes(want) ? 3 : -4;
            if (who && (t.includes(who) || ch.includes(who))) s += 2;
            // Loose on purpose: uploaders misspell "Official" ("Offical Video") all the time.
            const clip = /\bvideo\b|видео|клип|\bmv\b/.test(t) || ch.endsWith("vevo");
            if (clip) s += 3;
            if (bad.test(t) && !bad.test(title.toLowerCase())) s -= 5;
            const d = e.duration || 0;
            if (!d) s -= 1;
            else if (length > 0) s += (d - length >= -15 && d - length <= 120) ? 2 : -2;
            return { id: e.id, title: e.title || "", duration: d, score: s, clip };
        }).sort((a, b) => b.score - a.score);
    }

    function good(c) { return c && c.clip && c.score >= 5; }

    function parse(text) {
        try { return JSON.parse(text).entries || []; } catch (e) { return []; }
    }

    // One process per search and per download: a new request never reuses the
    // process of the one before, whose late answer would show the wrong clip.
    property var searchJob: null
    property var fetchJob: null
    function cancel() {
        if (searchJob) searchJob.running = false;
        if (fetchJob) fetchJob.running = false;
        searchJob = null;
        fetchJob = null;
    }

    property bool pickAny: false   // user asked for "another clip": take whatever comes next
    function find(any) {
        pickAny = any;
        if (searchJob) return;     // already looking for this track
        status = "searching";
        searchJob = searchComp.createObject(root, {
            command: ["yt-dlp", "--no-warnings"].concat(Config.ytCookieArgs(), ["--flat-playlist", "-J", query(Player.artist, Player.title)])
        });
        searchJob.running = true;
    }

    Component {
        id: searchComp
        Process {
            id: search
            property string found: ""
            stdout: StdioCollector { onStreamFinished: search.found = text }
            onExited: code => {
                Qt.callLater(search.destroy);
                if (root.searchJob !== search) return;
                root.searchJob = null;
                const ranked = code === 0 ? root.rank(root.parse(found), Player.artist, Player.title, Player.length) : [];
                root.candidates = ranked;
                const best = ranked[0];
                if (best && (root.pickAny || root.good(best))) {
                    root.choice = 0;
                    root.use(best);
                    root.remember(root.key, best);
                } else {
                    root.status = "none";
                }
            }
        }
    }

    // ---- Download into the cache (or reuse), then play from disk

    function fetchCommand(id) {
        return ["sh", "-c", Cache.pruneFn +
            'dir="$1"; id="$2"; vid="$6"; mkdir -p "$dir"; ' +
            'f=$(ls "$dir/$id".* 2>/dev/null | grep -v "\\.part$" | head -1); ' +
            'if [ -z "$f" ]; then yt-dlp --no-warnings -q ${4:+--cookies-from-browser "$4"} -N 8 --http-chunk-size 2M -f "$3" -o "$dir/$id.%(ext)s" "https://www.youtube.com/watch?v=$vid" || exit 1; ' +
            'f=$(ls "$dir/$id".* 2>/dev/null | grep -v "\\.part$" | head -1); fi; ' +
            '[ -n "$f" ] || exit 1; touch "$f"; ' +
            'prune "$dir" "$5"; ' +
            'echo "$f"',
            "sh", clipsDir, quality === 480 ? id : id + "-" + quality, format, Config.youtubeCookies,
            String(Cache.limitBytes(Config.clipCacheMB)), id];
    }

    function use(c) {
        videoId = c.id;
        videoTitle = c.title || "";
        videoDuration = c.duration || 0;
        streamUrl = "";
        status = "loading";
        if (fetchJob) fetchJob.running = false;
        fetchJob = fetchComp.createObject(root, { command: fetchCommand(c.id) });
        fetchJob.running = true;
    }

    // A new quality applies to the clip on screen right away.
    Connections {
        target: Config
        function onClipQualityChanged() {
            if (root.videoId !== "" && !root.searchJob)
                root.use({ id: root.videoId, title: root.videoTitle, duration: root.videoDuration });
        }
    }

    Component {
        id: fetchComp
        Process {
            id: fetch
            property string out: ""
            stdout: SplitParser { onRead: line => fetch.out = line.trim() }
            onExited: code => {
                Qt.callLater(fetch.destroy);
                if (root.fetchJob !== fetch) return;
                root.fetchJob = null;
                if (code === 0 && out.startsWith("/")) {
                    root.streamUrl = "file://" + out;
                    root.status = "ready";
                } else {
                    root.status = "none";
                }
            }
        }
    }

    // ---- User choices

    // Step to the next candidate (searching first if needed) and remember it.
    function next() {
        if (key === "") return;
        if (candidates.length === 0) { find(true); return; }
        choice = (choice + 1) % candidates.length;
        const c = candidates[choice];
        use(c);
        remember(key, c);
    }

    // "No clip for this track", remembered.
    function hide() {
        if (key === "") return;
        const picks = Object.assign({}, cache.picks);
        picks[key] = { none: true };
        cache.picks = picks;
        streamUrl = "";
        status = "none";
    }

    function remember(k, c) {
        const picks = Object.assign({}, cache.picks);
        picks[k] = { id: c.id, title: c.title, duration: c.duration };
        cache.picks = picks;
    }

    // ---- Prefetch the next Spotify track's clip while this one plays

    readonly property var upNext: Queue.items[0]
        ?? (Spotify.connected && Player.source === "spotify" ? (Spotify.queue[0] ?? null) : null)
    readonly property string upNextKey: upNext ? keyFor(upNext.artist, upNext.title) : ""
    onUpNextKeyChanged: prefetchDelay.restart()

    Timer {
        id: prefetchDelay
        interval: 8000
        onTriggered: {
            const k = root.upNextKey;
            if (!root.enabled || !k || k === root.key || cache.picks[k] || prefetchSearch.running || prefetchFetch.running) return;
            prefetchSearch.target = root.upNext;
            prefetchSearch.command = ["yt-dlp", "--no-warnings"].concat(Config.ytCookieArgs(), ["--flat-playlist", "-J", root.query(root.upNext.artist, root.upNext.title)]);
            prefetchSearch.running = true;
        }
    }

    Process {
        id: prefetchSearch
        property var target: null
        stdout: StdioCollector {
            onStreamFinished: {
                const t = prefetchSearch.target;
                if (!t) return;
                const best = root.rank(root.parse(text), t.artist, t.title, t.length || 0)[0];
                const k = root.keyFor(t.artist, t.title);
                if (root.good(best)) {
                    root.remember(k, best);
                    prefetchFetch.command = root.fetchCommand(best.id);
                    prefetchFetch.running = true;
                } else {
                    const picks = Object.assign({}, cache.picks);
                    picks[k] = { none: true };
                    cache.picks = picks;
                }
            }
        }
    }

    Process { id: prefetchFetch }

    // ---- Remembered choices

    FileView {
        id: file
        path: root.cacheDir + "/clips.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) mkdir.running = true; }

        JsonAdapter {
            id: cache
            property var picks: ({})
        }
    }

    Process {
        id: mkdir
        command: ["mkdir", "-p", root.cacheDir]
        onExited: file.writeAdapter()
    }
}
