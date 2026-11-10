pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Afterglow's own play queue, across services. Spotify tracks are started in
// Spotify; everything else plays in LocalPlayer. When a track ends the next one
// starts by itself. If the user changes the track in Spotify mid-song, the
// engine steps back (the queue stays) and can be resumed.
// Upcoming items persist in ~/.local/share/afterglow/queue.json.
Singleton {
    id: root

    // item: { title, artist, album, art, uri, source, length }
    property var items: []
    property var current: null
    property bool active: false        // the engine is driving playback

    readonly property bool localActive: active && current !== null && current.source !== "spotify"
    readonly property bool spotifyActive: active && current !== null && current.source === "spotify"

    // ---- Editing

    function norm(t) {
        return {
            title: t.title || "",
            artist: t.artist || "",
            album: t.album || "",
            art: t.art || "",
            uri: t.uri || "",
            source: t.source || (String(t.uri).startsWith("spotify:") ? "spotify" : "youtube"),
            length: t.length || 0,
            auto: t.auto === true      // picked by autoplay, not by the user
        };
    }

    function add(t) {
        if (!t?.uri) return;
        // The user's own tracks go before autoplay picks.
        const at = items.findIndex(x => x.auto);
        const next = items.slice();
        next.splice(at < 0 ? next.length : at, 0, norm(t));
        items = next;
        Spotify.say("В очереди: " + t.title);
        prefetchNext();
    }

    function addNext(t) {
        if (!t?.uri) return;
        items = [norm(t)].concat(items);
        Spotify.say("Следующим: " + t.title);
        prefetchNext();
    }

    // A whole playlist or album: to the end (before autoplay picks), or play it now.
    function addAll(list) {
        if (!list?.length) return;
        const at = items.findIndex(x => x.auto);
        const next = items.slice();
        next.splice(at < 0 ? next.length : at, 0, ...list.map(norm));
        items = next;
        Spotify.say("В очереди: " + list.length + " треков");
        prefetchNext();
    }
    function playAll(list) {
        if (!list?.length) return;
        items = list.slice(1).map(norm).concat(items.filter(x => !x.auto));
        start(norm(list[0]));
    }

    function remove(i) {
        const next = items.slice();
        next.splice(i, 1);
        items = next;
    }

    function move(i, delta) {
        const j = i + delta;
        if (j < 0 || j >= items.length) return;
        const next = items.slice();
        const [it] = next.splice(i, 1);
        next.splice(j, 0, it);
        items = next;
    }

    function clear() { items = []; }

    // ---- Playback

    function playNow(t) {
        if (!t?.uri) return;
        start(norm(t));
    }

    function playAt(i) {
        const t = items[i];
        if (!t) return;
        remove(i);
        start(t);
    }

    function advance() {
        if (items.length === 0 && Config.autoplayLiked) autofill(3);
        if (items.length === 0) { finish(); return; }
        const t = items[0];
        items = items.slice(1);
        start(t);
        // Keep autoplay topped up so the carousel always shows what comes next.
        if (t.auto && Config.autoplayLiked && items.length < 2) autofill(3);
    }

    // After the user's queue: random tracks from Spotify's liked songs and the
    // SoundCloud tracks in the history, skipping anything played recently.
    function autofill(n) {
        const recent = new Set(History.tracks.slice(0, 40).map(h => h.title + "\u0001" + h.artist));
        for (const t of items) recent.add(t.title + "\u0001" + t.artist);
        if (current) recent.add(current.title + "\u0001" + current.artist);
        const pool = [];
        for (const t of Spotify.liked) pool.push(t);
        for (const t of Accounts.ytmLiked) pool.push(t);
        for (const t of Accounts.scLikes) pool.push(t);
        for (const h of History.tracks) if (h.source === "soundcloud" && h.uri) pool.push(h);
        const fresh = pool.filter(t => t.uri && !recent.has(t.title + "\u0001" + t.artist));
        const from = fresh.length ? fresh : pool;
        const picked = [];
        while (picked.length < n && from.length) {
            const t = from.splice(Math.floor(Math.random() * from.length), 1)[0];
            picked.push(norm(Object.assign({}, t, { auto: true })));
        }
        if (picked.length) items = items.concat(picked);
    }

    // Restart the track, or go back to the previous one in the history.
    function back() {
        if (Player.position > 3) { Player.setPosition(0); return; }
        const prev = History.tracks.find(h => !(h.title === Player.title && h.artist === Player.artist));
        if (prev) {
            if (current) items = [current].concat(items);
            start(norm(prev));
        } else {
            Player.setPosition(0);
        }
    }

    // Pick up the queue again after the user took over.
    function resume() { if (!active) advance(); }

    function start(t) {
        current = t;
        active = true;
        watch.matched = false;
        watch.nearEnd = false;
        watch.waited = 0;
        if (t.source === "spotify") {
            LocalPlayer.stop();
            Spotify.playTrack(t.uri);
        } else {
            const sp = Player.playerFor("spotify");
            if (sp?.isPlaying) sp.pause();
            LocalPlayer.load(t);
        }
        prefetchNext();
    }

    // Queue ran out: local playback stops; Spotify is left to carry on by itself.
    function finish() {
        if (localActive) LocalPlayer.stop();
        active = false;
        current = null;
    }

    // The user took over in another player.
    function release() {
        active = false;
        current = null;
    }

    // Download the next three non-Spotify tracks ahead of time.
    function prefetchNext() {
        LocalPlayer.prefetch(items.filter(t => t.source !== "spotify").slice(0, 3));
    }

    Connections {
        target: LocalPlayer
        function onEnded() { if (root.localActive) root.advance(); }
        function onFailed(why) {
            if (!root.localActive) return;
            console.warn("Afterglow: skipping", root.current?.uri, why);
            if (/not a bot|Sign in to confirm/i.test(why) && !Config.youtubeCookies)
                Spotify.say("YouTube требует вход: включи youtubeCookies в настройках");
            else
                Spotify.say("Не получилось включить «" + (root.current?.title ?? "") + "», дальше");
            skipFailed.restart();
        }
    }

    Timer {
        id: skipFailed
        interval: 1500
        onTriggered: if (root.localActive && LocalPlayer.status === "error") root.advance()
    }

    // Spotify gives no "track finished" event: watch its MPRIS state instead.
    Timer {
        id: watch
        property bool matched: false
        property bool nearEnd: false
        property int waited: 0
        running: root.spotifyActive
        interval: 500
        repeat: true
        onTriggered: {
            const p = Player.playerFor("spotify");
            if (!p) return;
            p.positionChanged();
            const id = String(p.metadata?.["mpris:trackid"] ?? "");
            const url = String(p.metadata?.["xesam:url"] ?? "");
            const m = id.match(/spotify\/track\/(\w+)/) || url.match(/open\.spotify\.com\/track\/(\w+)/);
            const uri = m ? "spotify:track:" + m[1] : "";
            if (uri === root.current.uri) {
                matched = true;
                if (p.length > 0 && p.position >= p.length - 2.5) nearEnd = true;
                // Next is not on Spotify: hand over just before the end, so Spotify's
                // autoplay does not slip a track of its own in between.
                const next = root.items[0];
                if (nearEnd && next && next.source !== "spotify" && p.position >= p.length - 0.8) root.advance();
                else if (nearEnd && !p.isPlaying) root.advance();
            } else if (matched) {
                // Moved on by itself at the end: ours is next. Mid-song: the user took over.
                if (nearEnd) root.advance(); else root.release();
            } else if (++waited > 50) {
                // Spotify never picked the track up (no device, no Premium...).
                Spotify.say("Spotify не включил трек, пропускаю");
                root.advance();
            }
        }
    }

    // ---- Persistence
    // The queue lives in memory and is saved shortly after each change; the file is
    // read once at start. (A live JsonAdapter re-read the file between rapid edits
    // and rolled them back.)

    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/afterglow"
    property bool loaded: false
    onItemsChanged: if (loaded) save.restart()

    FileView {
        id: file
        path: root.dir + "/queue.json"
        onLoaded: {
            try { root.items = JSON.parse(text()).items || []; } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }

    Process {
        id: mkdir
        running: true
        command: ["mkdir", "-p", root.dir]
    }

    Timer {
        id: save
        interval: 400
        onTriggered: file.setText(JSON.stringify({ items: root.items }, null, 1))
    }
}
