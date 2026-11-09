pragma Singleton
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

// Afterglow's own audio player for tracks that are not on Spotify (YouTube,
// YouTube Music, SoundCloud, links yt-dlp understands). The audio is fetched with
// yt-dlp into ~/.cache/afterglow/audio and played from disk: YouTube refuses its
// stream URLs to other players, and a cached file starts instantly next time.
Singleton {
    id: root

    property var item: null          // { title, artist, album, art, uri, source, length }
    // "idle" | "loading" | "ready" | "error"
    property string status: "idle"
    property real volume: 0.8

    readonly property bool active: item !== null
    // The player (and FFmpeg behind it) exists only while a track is loaded here.
    readonly property var media: holder.item
    readonly property bool isPlaying: media !== null && media.playbackState === MediaPlayer.PlayingState
    readonly property bool loading: status === "loading"
    readonly property real position: media ? media.position / 1000 : 0
    readonly property real length: media && media.duration > 0 ? media.duration / 1000 : (item?.length ?? 0)

    signal ended
    signal failed(string why)

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/afterglow/audio"

    Loader {
        id: holder
        active: root.item !== null
        sourceComponent: MediaPlayer {
            audioOutput: AudioOutput { volume: root.volume }
            onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia) root.ended()
            onErrorOccurred: (error, message) => {
                root.status = "error";
                root.failed(message);
            }
        }
    }


    function hash(s) {
        let h = 5381;
        for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
        return (h >>> 0).toString(16);
    }

    // YouTube throttles single-stream downloads; 512K chunks over 8 connections cut
    // a typical track from ~20 s to ~7 s. `alt` is the fallback format for a retry.
    function fetchCommand(url, alt) {
        return ["sh", "-c", Cache.pruneFn +
            'dir="$1"; id="$2"; mkdir -p "$dir"; ' +
            'f=$(ls "$dir/$id".* 2>/dev/null | grep -v "\\.part$" | head -1); ' +
            'if [ -z "$f" ]; then yt-dlp --no-warnings -q --no-playlist ${5:+--cookies-from-browser "$5"} -N 8 --http-chunk-size 512K -f "$4" -o "$dir/$id.%(ext)s" "$3" || exit 1; ' +
            'f=$(ls "$dir/$id".* 2>/dev/null | grep -v "\\.part$" | head -1); fi; ' +
            '[ -n "$f" ] || exit 1; touch "$f"; ' +
            'prune "$dir" "$6"; ' +
            'echo "$f"',
            "sh", cacheDir, hash(url), url, alt ? "bestaudio/best" : "ba[ext=m4a]/ba/b", Config.youtubeCookies,
            String(Cache.limitBytes(Config.audioCacheMB))];
    }

    function load(it) {
        if (media) { media.stop(); media.source = ""; }
        item = it;
        status = "loading";
        fetch.out = "";
        fetch.forUri = it.uri;
        fetch.retried = false;
        fetch.command = fetchCommand(it.uri, false);
        // Already downloading in the background: wait for it instead of racing it.
        if (pre.running && pre.uri === it.uri) waitForPre = true;
        else fetch.running = true;
    }
    property bool waitForPre: false

    Process {
        id: fetch
        property string out: ""
        property string forUri: ""
        property string err: ""
        property bool retried: false
        stdout: SplitParser { onRead: line => fetch.out = line.trim() }
        stderr: SplitParser { onRead: line => fetch.err = line }
        onStarted: err = ""
        onExited: code => {
            if (forUri !== root.item?.uri) return;
            if (code === 0 && out.startsWith("/")) {
                root.status = "ready";
                if (root.media) {
                    root.media.source = "file://" + out;
                    root.media.play();
                }
            } else if (!retried) {
                console.warn("Afterglow: audio fetch failed, retrying:", forUri, err);
                retried = true;
                out = "";
                command = root.fetchCommand(forUri, true);
                running = true;
            } else {
                console.warn("Afterglow: audio fetch failed:", forUri, err);
                root.status = "error";
                root.failed(err || "yt-dlp не смог получить звук");
            }
        }
    }

    // Warm the cache for what plays next, one download at a time.
    property var pending: []
    function prefetch(list) {
        const want = list.filter(t => t && t.source !== "spotify").map(t => t.uri);
        pending = want.filter(u => u !== pre.uri);
        if (!pre.running) pre.next();
    }
    Process {
        id: pre
        property string uri: ""
        function next() {
            if (root.pending.length === 0) { uri = ""; return; }
            uri = root.pending[0];
            root.pending = root.pending.slice(1);
            command = root.fetchCommand(uri, false);
            running = true;
        }
        onExited: {
            if (root.waitForPre && uri === root.item?.uri) {
                root.waitForPre = false;
                fetch.running = true;   // the file is cached now: starts at once
            }
            next();
        }
    }

    function play() { if (active && status === "ready" && media) media.play(); }
    function pause() { if (media) media.pause(); }
    function toggle() { if (isPlaying) pause(); else play(); }
    function seek(sec) { if (media?.seekable) media.position = Math.max(0, sec * 1000); }

    function stop() {
        waitForPre = false;
        fetch.running = false;
        if (media) { media.stop(); media.source = ""; }
        item = null;
        status = "idle";
    }
}
