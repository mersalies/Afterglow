pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// What is playing, wherever it plays: Afterglow's own LocalPlayer while the queue
// runs a non-Spotify track, otherwise the "current" MPRIS player (Spotify,
// browsers, mpv, ...). Also derives a colour palette from the cover.
Singleton {
    id: root

    property MprisPlayer last: null
    readonly property MprisPlayer active: {
        const ps = Mpris.players.values;
        if (Config.source !== "auto") {
            const own = ps.filter(p => sourceKey(p) === Config.source);
            if (own.length) return own.find(p => p.isPlaying) ?? own[0];
        }
        const playing = ps.find(p => p.isPlaying);
        if (playing) return playing;
        // Nothing plays: the default player from the settings, when it is open.
        if (Config.defaultPlayer) {
            const fav = ps.find(p => sourceKey(p) === Config.defaultPlayer);
            if (fav) return fav;
        }
        if (last && ps.includes(last)) return last;
        return ps[0] ?? null;
    }
    // Deferred so writing `last` does not re-enter the `active` binding.
    onActiveChanged: if (active) Qt.callLater(() => { if (active) last = active; })

    // Afterglow is playing a queued track itself.
    readonly property bool local: Queue.localActive
    readonly property var item: LocalPlayer.item

    readonly property bool hasPlayer: local || active !== null
    readonly property bool isPlaying: local ? LocalPlayer.isPlaying : (active?.isPlaying ?? false)
    readonly property string title: local ? (item?.title ?? "") : (active?.trackTitle || "")
    readonly property string artist: local ? (item?.artist ?? "") : (active?.trackArtist || "")
    readonly property string album: local ? (item?.album ?? "") : (active?.trackAlbum || "")
    readonly property string artUrl: local ? (item?.art ?? "") : (active?.trackArtUrl || "")
    readonly property real length: local ? LocalPlayer.length : (active?.length ?? 0)
    readonly property real position: local ? LocalPlayer.position : (active?.position ?? 0)
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0
    readonly property string identity: local ? "Afterglow" : (active?.identity || "")
    readonly property string source: local ? (item?.source ?? "") : sourceKey(active)
    readonly property string sourceLabel: local ? "Afterglow · " + sourceName(source, null) : sourceName(source, active)

    readonly property bool canSeek: local ? LocalPlayer.status === "ready" : (active?.canSeek ?? false)
    readonly property bool canToggle: local ? LocalPlayer.status === "ready" : (active?.canTogglePlaying ?? false)
    readonly property bool canNext: Queue.active ? true : (active?.canGoNext ?? false)
    readonly property bool canPrevious: Queue.active ? true : (active?.canGoPrevious ?? false)
    readonly property bool volumeSupported: local || (active?.volumeSupported ?? false)
    readonly property real volume: local ? LocalPlayer.volume : (active?.volume ?? 0)

    function setVolume(v) {
        v = Math.max(0, Math.min(1, v));
        if (local) LocalPlayer.volume = v;
        else if (active?.volumeSupported) active.volume = v;
    }
    function setPosition(sec) {
        if (local) LocalPlayer.seek(sec);
        else if (active?.canSeek) active.position = Math.max(0, sec);
    }

    // spotify:track:ID for Spotify, otherwise the page URL the player reports
    readonly property string trackUri: {
        if (local) return item?.uri ?? "";
        const id = String(active?.metadata?.["mpris:trackid"] ?? "");
        // The desktop app reports /com/spotify/track/ID, spotifyd a path of its own;
        // both end in spotify/track/ID. Fall back to an open.spotify.com URL.
        const url = String(active?.metadata?.["xesam:url"] ?? "");
        const m = id.match(/spotify\/track\/(\w+)/) || url.match(/open\.spotify\.com\/track\/(\w+)/);
        if (m) return "spotify:track:" + m[1];
        return String(active?.metadata?.["xesam:url"] ?? "");
    }

    // ---- Sources: one entry per kind of player (Spotify app, a browser tab on VK, ...)

    function sourceKey(p) {
        if (!p) return "";
        const id = (p.identity || "").toLowerCase();
        const bus = (p.dbusName || "").toLowerCase();
        if (id.includes("spotify") || bus.includes("spotify")) return "spotify";
        if (id.includes("yandex") || bus.includes("yandex")) return "yandex";
        const url = String(p.metadata?.["xesam:url"] ?? "");
        const host = (url.match(/^https?:\/\/([^/]+)/) || [])[1] || "";
        if (host.includes("music.youtube")) return "youtube-music";
        if (host.includes("youtube") || host.includes("youtu.be")) return "youtube";
        if (host.includes("vk.com") || host.includes("vk.ru")) return "vk";
        if (host.includes("soundcloud")) return "soundcloud";
        if (host.includes("music.yandex")) return "yandex";
        if (host.includes("open.spotify")) return "spotify-web";
        return bus.replace(/^org\.mpris\.mediaplayer2\./, "").split(".")[0] || id || "player";
    }

    readonly property var sourceNames: ({
        "spotify": "Spotify", "spotify-web": "Spotify Web", "yandex": "Яндекс Музыка",
        "youtube-music": "YouTube Music", "youtube": "YouTube", "vk": "VK Музыка", "soundcloud": "SoundCloud"
    })
    readonly property var sourceColors: ({
        "spotify": "#1ed760", "spotify-web": "#1ed760", "yandex": "#ffcc00",
        "youtube-music": "#ff2d55", "youtube": "#ff2d55", "vk": "#2787f5", "soundcloud": "#ff6a1f"
    })
    function sourceName(key, p) { return sourceNames[key] ?? p?.identity ?? key; }
    function sourceColor(key) { return sourceColors[key] ?? "#c8c8d0"; }

    // [{ key, name, color, playing, title }]
    readonly property var sources: {
        const out = [];
        for (const p of Mpris.players.values) {
            const key = sourceKey(p);
            const prev = out.find(o => o.key === key);
            if (prev) { if (p.isPlaying) { prev.playing = true; prev.title = p.trackTitle; } continue; }
            out.push({ key, name: sourceName(key, p), color: sourceColor(key), playing: p.isPlaying, title: p.trackTitle || "" });
        }
        return out;
    }

    function playerFor(key) {
        const own = Mpris.players.values.filter(p => sourceKey(p) === key);
        return own.find(p => p.isPlaying) ?? own[0] ?? null;
    }

    function toggle() {
        if (local) LocalPlayer.toggle();
        else if (active?.canTogglePlaying) active.togglePlaying();
        else if (!active) startDefault();
    }

    // Play with no player around: start the default one from the settings.
    readonly property var defaultPages: ({
        "youtube-music": "https://music.youtube.com", "yandex": "https://music.yandex.ru",
        "vk": "https://vk.com/audio", "soundcloud": "https://soundcloud.com", "apple": "https://music.apple.com"
    })
    function startDefault() {
        const d = Config.defaultPlayer;
        if (d === "spotify") {
            if (Spotify.connected) Spotify.launchAndPlay(null, "");
            else Qt.openUrlExternally("spotify:");
        }
        else if (defaultPages[d]) Qt.openUrlExternally(defaultPages[d]);
        else Queue.resume();
    }
    // While Afterglow's queue runs, next/previous walk the queue, not the player's own list.
    function next() {
        if (Queue.active) Queue.advance();
        else if (active?.canGoNext) active.next();
    }
    function previous() {
        if (Queue.active) Queue.back();
        else if (active?.canGoPrevious) active.previous();
    }
    function seekTo(fraction) {
        if (length > 0) setPosition(fraction * length);
    }

    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) sec = 0;
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // MPRIS does not push position updates; poll while playing.
    Timer {
        running: root.isPlaying
        interval: 80
        repeat: true
        onTriggered: root.active?.positionChanged()
    }

    // ---- Cover art: remote covers are cached locally so the quantizer can read them.

    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/afterglow/art"
    property string localArt: ""

    function hash(s) {
        let h = 5381;
        for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
        return (h >>> 0).toString(16);
    }

    // Covers are copied into ~/.cache so history keeps them after the player forgets them.
    onArtUrlChanged: {
        if (artUrl === "") {
            localArt = "";
            return;
        }
        const target = cacheDir + "/" + hash(artUrl + "|" + title);
        const remote = artUrl.startsWith("http");
        const src = remote ? artUrl : decodeURIComponent(artUrl.replace(/^file:\/\//, ""));
        fetchArt.target = target;
        fetchArt.command = ["sh", "-c", Cache.pruneFn + (remote
            ? 'mkdir -p "$1" && { [ -s "$2" ] || { curl -sfL --max-time 10 -o "$2.part" "$3" && mv "$2.part" "$2"; }; }'
            : 'mkdir -p "$1" && cp -f "$3" "$2"') + '; s=$?; touch "$2" 2>/dev/null; prune "$1" "$4"; exit $s',
            "sh", cacheDir, target, src, String(Cache.limitBytes(Config.artCacheMB))];
        fetchArt.running = true;
        if (!remote) localArt = artUrl;
    }

    Process {
        id: fetchArt
        property string target
        onExited: code => { if (code === 0) root.localArt = "file://" + target; }
    }

    // ---- Palette

    ColorQuantizer {
        id: quant
        source: root.localArt
        depth: 3
        rescaleSize: 64
    }

    readonly property var palette: pickPalette(quant.colors)
    readonly property color accent: palette[0]
    readonly property color accent2: palette[1]
    readonly property color accent3: palette[2]
    // Dark tint for the glass card.
    readonly property color tint: Qt.hsva(accent.hsvHue, Math.min(0.6, accent.hsvSaturation), 0.18, 1)

    function pickPalette(cols) {
        const fallback = [Qt.color("#8b5cf6"), Qt.color("#ec4899"), Qt.color("#38bdf8")];
        if (!cols || cols.length === 0) return fallback;

        const scored = [];
        for (let i = 0; i < cols.length; i++) {
            const c = cols[i];
            const score = c.hsvSaturation * 0.7 + c.hsvValue * 0.3 - (c.hsvValue < 0.15 ? 1 : 0);
            scored.push({ c, score });
        }
        scored.sort((a, b) => b.score - a.score);

        const out = [];
        const hueDist = (a, b) => {
            const d = Math.abs(a.hsvHue - b.hsvHue);
            return Math.min(d, 1 - d);
        };
        for (const s of scored) {
            if (out.length >= 3) break;
            if (out.every(o => hueDist(o, s.c) > 0.06 || Math.abs(o.hsvValue - s.c.hsvValue) > 0.3)) out.push(s.c);
        }
        while (out.length < 3) out.push(out.length ? Qt.lighter(out[0], 1.3 + out.length * 0.2) : fallback[out.length]);

        // Make the glow colours bright enough to read as light.
        return out.map(c => Qt.hsva(c.hsvHue, Math.max(c.hsvSaturation, 0.35), Math.max(c.hsvValue, 0.75), 1));
    }
}
