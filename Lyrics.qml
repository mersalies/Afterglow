pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Time-synced lyrics for the playing track: the user's own .lrc files first, then
// LRCLIB (https://lrclib.net), NetEase Cloud Music and YouTube Music.
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

    readonly property string folder: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/afterglow/lyrics"
    readonly property string ytmHelper: Quickshell.shellDir + "/lyrics-ytm.py"

    // Sources in order; each calls back with { synced, plain } (LRC text, plain
    // text, or empty). The first synced result wins; the first plain one is kept
    // in case nothing synced turns up.
    //   1. the user's own .lrc in ~/.local/share/afterglow/lyrics (always wins)
    //   2. LRCLIB   3. NetEase Cloud Music   4. YouTube Music (unofficial)
    function load() {
        const k = key;
        if (k === "") { apply({ lines: [], synced: false }); status = "idle"; return; }
        if (cache[k]) { apply(cache[k]); return; }

        status = "loading";
        lines = [];
        const t = {
            artist: Player.artist, title: Player.title, album: Player.album, len: Player.length,
            first: Player.artist.split(/\/|,|&| feat\.?| ft\.?| x /i)[0].trim(),
            clean: cleanTitle(Player.title)
        };
        const sources = [fromFolder, fromLrclib, fromNetease, fromYoutubeMusic];

        let fallback = "";
        const next = i => {
            if (k !== root.key) return;
            if (i >= sources.length) { finish(k, "", fallback); return; }
            sources[i](t, res => {
                if (k !== root.key) return;
                if (res?.synced) { finish(k, res.synced, ""); return; }
                if (res?.plain && !fallback) fallback = res.plain;
                // A plain file of the user's own beats anything found online.
                if (i === 0 && fallback) { finish(k, "", fallback); return; }
                next(i + 1);
            });
        };
        next(0);
    }

    // Lowercase letters and digits only, so "Artist - Title (Live).lrc" and the
    // player's tags compare equal.
    function norm(s) {
        return (s || "").toLowerCase().replace(/ё/g, "е").replace(/[\s.,'"`’!?¿¡()\[\]{}\-–—_&:;\/\\|+*#@$%^~<>=]+/g, "");
    }

    // ---- 1. Own files: "Artist - Title.lrc" or "Title.lrc", any case, subfolders too.
    // A file without time stamps counts as plain lyrics.
    function fromFolder(t, done) {
        const want = [norm(t.artist + t.title), norm(t.first + t.title), norm(t.first + t.clean),
                      norm(t.title), norm(t.clean)];
        run(["sh", "-c", 'mkdir -p "$1"; find -L "$1" -maxdepth 3 -type f \\( -iname "*.lrc" -o -iname "*.txt" \\)', "sh", folder], text => {
            const files = text.split("\n").filter(f => f);
            const name = f => norm(f.slice(f.lastIndexOf("/") + 1).replace(/\.(lrc|txt)$/i, ""));
            let hit = "";
            for (const w of want) {
                hit = files.find(f => name(f) === w) || "";
                if (hit) break;
            }
            if (!hit) { done(null); return; }
            run(["cat", hit], body => done(/\[\d+:\d+(\.\d+)?\]/.test(body) ? { synced: body } : { plain: body }));
        });
    }

    // A helper process per request: cb(stdout) exactly once, when it has ended.
    // (A shared process restarted for the next track answered for it with the
    // cut-off output of the one before.)
    function run(command, cb) {
        runComp.createObject(root, { command, cb, running: true });
    }
    Component {
        id: runComp
        Process {
            id: rp
            property var cb
            property string got: ""
            stdout: StdioCollector { onStreamFinished: rp.got = text }
            onExited: { rp.cb(rp.got); Qt.callLater(rp.destroy); }
        }
    }

    // ---- 2. LRCLIB, most exact first:
    //   exact match with album and duration, without album, field search
    //   (track + first artist), free-text search. Results ranked by synced
    //   lyrics, then by closeness of duration.
    function fromLrclib(t, done) {
        const enc = encodeURIComponent;
        const base = "https://lrclib.net/api/";
        const pick = list => {
            if (!Array.isArray(list) || !list.length) return null;
            const near = x => t.len > 0 && x.duration ? Math.abs(x.duration - t.len) : 0;
            const ok = list.filter(x => !t.len || !x.duration || near(x) < 12);
            ok.sort((a, b) => (!!b.syncedLyrics - !!a.syncedLyrics) || (near(a) - near(b)));
            return ok[0] ?? null;
        };
        const steps = [];
        if (t.album && t.len > 0) steps.push(base + "get?artist_name=" + enc(t.artist) + "&track_name=" + enc(t.title) + "&album_name=" + enc(t.album) + "&duration=" + Math.round(t.len));
        steps.push(base + "get?artist_name=" + enc(t.first) + "&track_name=" + enc(t.clean) + (t.len > 0 ? "&duration=" + Math.round(t.len) : ""));
        steps.push(base + "search?track_name=" + enc(t.clean) + "&artist_name=" + enc(t.first));
        steps.push(base + "search?q=" + enc(t.clean + " " + t.first));

        let plain = "";
        const next = i => {
            if (i >= steps.length) { done({ plain: plain }); return; }
            request(steps[i], (ok, data) => {
                const hit = Array.isArray(data) ? pick(data) : (ok ? data : null);
                if (hit?.syncedLyrics) { done({ synced: hit.syncedLyrics }); return; }
                if (hit?.plainLyrics && !plain) plain = hit.plainLyrics;
                next(i + 1);
            });
        };
        next(0);
    }

    // ---- 3. NetEase Cloud Music: big catalogue with synced lyrics, also for
    // Russian and Asian music. Its search is loose, so a hit must match the first
    // artist, the title and (when known) the duration.
    function fromNetease(t, done) {
        const a = norm(t.first), c = norm(t.clean);
        if (!a || !c) { done(null); return; }
        const q = encodeURIComponent(t.first + " " + t.clean);
        request("https://music.163.com/api/search/get?type=1&limit=10&s=" + q, (ok, data) => {
            const songs = ok ? (data?.result?.songs ?? []) : [];
            const song = songs.find(s => {
                const name = norm(s.name), artists = norm((s.artists || []).map(x => x.name).join(""));
                const len = (s.duration || 0) / 1000;
                return artists.includes(a) && (name === c || name.startsWith(c) || c.startsWith(name) && name.length > 2)
                    && (!t.len || !len || Math.abs(len - t.len) < 12);
            });
            if (!song) { done(null); return; }
            request("https://music.163.com/api/song/lyric?lv=1&id=" + song.id, (ok2, lyr) => {
                const text = ok2 ? (lyr?.lrc?.lyric ?? "") : "";
                // Drop the credit lines NetEase puts first ("作词 : …", "作曲 : …").
                const body = text.split("\n").filter(l => !/^\s*(\[[^\]]*\])+\s*[一-鿿]+\s*[:：]/.test(l)).join("\n");
                if (/\[\d+:\d+(\.\d+)?\]\s*\S/.test(body)) done({ synced: body });
                else done(null);
            });
        });
    }

    // ---- 4. YouTube Music through lyrics-ytm.py: often has Russian lyrics,
    // synced when the app shows them in time. Unofficial, may stop working.
    function fromYoutubeMusic(t, done) {
        run(["timeout", "25", "python3", "-I", ytmHelper, t.artist, t.title], text => {
            const lrc = /^\[\d+:\d+(\.\d+)?\]/m.test(text);
            done(text.trim() === "" ? null : lrc ? { synced: text } : { plain: text });
        });
    }

    function finish(k, synced, plain) {
        let entry = { lines: [], synced: false };
        if (synced) entry = { lines: parseLrc(synced), synced: true };
        else if (plain) entry = {
            lines: plain.split("\n").filter(l => l.trim() !== "").map(t => ({ time: 0, text: t })),
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

    // A site that does not answer in 12 s counts as "nothing found", so the
    // next source gets its turn instead of "loading" for ever.
    function request(url, cb) {
        const xhr = new XMLHttpRequest();
        let over = false;
        const guard = guardComp.createObject(root, { hit: () => {
            if (over) return;
            over = true;
            xhr.abort();
            cb(false, null);
        } });
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || over) return;
            over = true;
            guard.destroy();
            if (xhr.status === 200) {
                try { cb(true, JSON.parse(xhr.responseText)); } catch (e) { cb(false, null); }
            } else cb(false, null);
        };
        xhr.open("GET", url);
        xhr.send();
    }
    Component {
        id: guardComp
        Timer {
            property var hit
            interval: 12000
            running: true
            onTriggered: { hit(); destroy(); }
        }
    }
}
