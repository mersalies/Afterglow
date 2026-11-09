pragma Singleton
import QtQuick
import Quickshell

// Time-synced lyrics from LRCLIB (https://lrclib.net), matched to the MPRIS track.
Singleton {
    id: root

    // [{ time: seconds, text: string }]
    property var lines: []
    property bool synced: false
    // "idle" | "loading" | "ready" | "none"
    property string status: "idle"

    readonly property string key: Player.title !== "" ? Player.artist + "\u0001" + Player.title : ""
    property var cache: ({})

    // Playback time used for lyrics: a little ahead so a line appears as it is
    // sung, plus the user's own correction (`lyricsOffset` in config.json).
    readonly property real now: Player.position + 0.2 + Config.lyricsOffset

    readonly property int index: {
        if (!synced || lines.length === 0) return -1;
        const t = now;
        let lo = 0, hi = lines.length - 1, res = -1;
        while (lo <= hi) {
            const mid = (lo + hi) >> 1;
            if (lines[mid].time <= t) { res = mid; lo = mid + 1; } else hi = mid - 1;
        }
        return res;
    }
    readonly property string current: index >= 0 ? lines[index].text : ""
    // 0..1 progress through the current line (karaoke sweep)
    readonly property real lineProgress: {
        if (index < 0) return 0;
        const start = lines[index].time;
        const end = index + 1 < lines.length ? lines[index + 1].time : Math.max(start + 4, Player.length);
        return Math.max(0, Math.min(1, (now - start) / Math.max(0.5, end - start)));
    }

    onKeyChanged: debounce.restart()

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.load()
    }

    function apply(entry) {
        lines = entry.lines;
        synced = entry.synced;
        status = entry.lines.length ? "ready" : "none";
    }

    // LRCLIB lookups, most exact first; stops at the first synced hit:
    //   1. exact match with album and duration   2. without album
    //   3. field search (track + first artist)    4. free-text search on the cleaned title
    // Search results are ranked by synced lyrics, then by closeness of duration.
    function load() {
        const k = key;
        if (k === "") { apply({ lines: [], synced: false }); status = "idle"; return; }
        if (cache[k]) { apply(cache[k]); return; }

        status = "loading";
        lines = [];
        const artist = Player.artist, title = Player.title, album = Player.album, len = Player.length;
        const first = artist.split(/,|&| feat\.?| ft\.?| x /i)[0].trim();
        const clean = cleanTitle(title);
        const enc = encodeURIComponent;
        const base = "https://lrclib.net/api/";

        const pick = list => {
            if (!Array.isArray(list) || !list.length) return null;
            const near = x => len > 0 && x.duration ? Math.abs(x.duration - len) : 0;
            const ok = list.filter(x => !len || !x.duration || near(x) < 12);
            ok.sort((a, b) => (!!b.syncedLyrics - !!a.syncedLyrics) || (near(a) - near(b)));
            return ok[0] ?? null;
        };

        const steps = [];
        if (album && len > 0) steps.push(base + "get?artist_name=" + enc(artist) + "&track_name=" + enc(title) + "&album_name=" + enc(album) + "&duration=" + Math.round(len));
        steps.push(base + "get?artist_name=" + enc(first) + "&track_name=" + enc(clean) + (len > 0 ? "&duration=" + Math.round(len) : ""));
        steps.push(base + "search?track_name=" + enc(clean) + "&artist_name=" + enc(first));
        steps.push(base + "search?q=" + enc(clean + " " + first));

        let fallback = null;   // plain lyrics, kept in case nothing synced turns up
        const next = i => {
            if (k !== root.key) return;
            if (i >= steps.length) { finish(k, fallback); return; }
            request(steps[i], (ok, data) => {
                if (k !== root.key) return;
                const hit = Array.isArray(data) ? pick(data) : (ok ? data : null);
                if (hit?.syncedLyrics) { finish(k, hit); return; }
                if (hit?.plainLyrics && !fallback) fallback = hit;
                next(i + 1);
            });
        };
        next(0);
    }

    function finish(k, data) {
        let entry = { lines: [], synced: false };
        if (data?.syncedLyrics) entry = { lines: parseLrc(data.syncedLyrics), synced: true };
        else if (data?.plainLyrics) entry = {
            lines: data.plainLyrics.split("\n").filter(l => l.trim() !== "").map(t => ({ time: 0, text: t })),
            synced: false
        };
        cache[k] = entry;
        apply(entry);
    }

    function cleanTitle(t) {
        return t.replace(/\s*[\(\[].*?[\)\]]/g, "").replace(/\s+-\s+.*$/, "").replace(/\s+(feat|ft)\.?\s.*$/i, "").trim();
    }

    function parseLrc(text) {
        const out = [];
        const re = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
        for (const raw of text.split("\n")) {
            const stamps = [];
            let m;
            re.lastIndex = 0;
            while ((m = re.exec(raw)) !== null) stamps.push(parseInt(m[1]) * 60 + parseFloat(m[2]));
            const body = raw.replace(re, "").trim();
            for (const s of stamps) out.push({ time: s, text: body || "♪" });
        }
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    function request(url, cb) {
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try { cb(true, JSON.parse(xhr.responseText)); } catch (e) { cb(false, null); }
            } else cb(false, null);
        };
        xhr.open("GET", url);
        xhr.send();
    }
}
