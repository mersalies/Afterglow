pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// "For you" on the search panel's first screen: what the service itself
// suggests from what was played here (History, Likes, SoundCloud likes).
//   youtube-music  similar artists from the most played artist's page, the
//                  radio of a song played here, the newest record of each
//   soundcloud     the "recommended" of the last SoundCloud tracks, their
//                  authors and a couple of their albums
//   youtube        the mix of the last video
//   spotify        Spotify closed recommendations and related artists to new
//                  apps: the similar artists come from YouTube Music, their
//                  newest records and songs are then found on Spotify
// Each service is asked once per half hour (or on the refresh button).
Singleton {
    id: root

    // platform -> { seed, artists, albums, tracks, at }
    property var store: ({})
    property var busy: ({})
    readonly property int ttl: 30 * 60 * 1000

    function of(platform) { return store[platform] ?? null; }
    function isBusy(platform) { return !!busy[platform]; }

    function put(platform, d) {
        const s = Object.assign({}, store);
        s[platform] = Object.assign({ seed: "", artists: [], albums: [], tracks: [] }, s[platform] ?? {}, d, { at: Date.now() });
        store = s;
    }
    function setBusy(platform, on) {
        const b = Object.assign({}, busy);
        b[platform] = on;
        busy = b;
    }

    // What was listened to, most played artists first.
    function seeds() {
        const played = History.tracks.concat(Likes.tracks);
        const count = {};
        for (const t of played.slice(0, 120)) {
            const a = (t.artist || "").split(/,\s*|\s+feat\.?\s+|\s+&\s+/i)[0].trim();
            if (a) count[a] = (count[a] || 0) + 1;
        }
        const artists = Object.keys(count).sort((a, b) => count[b] - count[a]).slice(0, 5);
        const videos = [];
        for (const t of played) {
            const m = (t.uri || "").match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([\w-]{11})/);
            if (m && !videos.includes(m[1])) videos.push(m[1]);
            if (videos.length >= 3) break;
        }
        const sc = played.concat(Accounts.scLikes).filter(t => /soundcloud\.com\/[^/]+\/[^/]+/.test(t.uri || "") && !/\/sets\//.test(t.uri))
            .map(t => t.uri.split("?")[0]);
        return { artists, videos, soundcloud: [...new Set(sc)].slice(0, 3) };
    }

    function want(platform, force) {
        if (isBusy(platform)) return;
        const have = of(platform);
        if (!force && have && Date.now() - have.at < ttl) return;
        const s = seeds();
        if (!s.artists.length && !s.videos.length && !s.soundcloud.length) return;
        setBusy(platform, true);
        const p = procComp.createObject(root, {
            platform,
            command: ["python3", "-I", Catalog.helper, "picks", platform, JSON.stringify(s)]
        });
        p.running = true;
    }

    // Spotify: the similar artists' newest records and a few songs, on Spotify.
    function spotifyFill(d) {
        if (!Spotify.connected) { put("spotify", { seed: d.seed, artists: d.artists, albums: [], tracks: [] }); return; }
        const names = (d.artists || []).slice(0, 6).map(a => a.name);
        const albums = new Array(names.length).fill(null);
        const songs = new Array(names.length).fill(null).map(() => []);
        let left = names.length;
        put("spotify", { seed: d.seed, artists: d.artists, albums: [], tracks: [] });
        if (!left) { setBusy("spotify", false); return; }
        const done = () => {
            if (--left > 0) return;
            // Songs taken in turns: one of each artist, then the next round.
            const tracks = [];
            for (let r = 0; r < 3; r++) for (const s of songs) if (s[r]) tracks.push(s[r]);
            put("spotify", { albums: albums.filter(a => a), tracks });
            setBusy("spotify", false);
        };
        const enc = encodeURIComponent;
        names.forEach((name, i) => {
            Spotify.api("GET", "/search?type=artist,track&limit=3&q=" + enc(name), null, (code, r) => {
                const a = code === 200 ? (r?.artists?.items ?? []).find(x => Lyrics.norm(x.name) === Lyrics.norm(name)) : null;
                if (!a) { done(); return; }
                songs[i] = (r?.tracks?.items ?? []).filter(t => (t.artists || []).some(x => x.id === a.id)).map(Spotify.trackFrom).filter(t => t);
                Spotify.api("GET", "/artists/" + a.id + "/albums?include_groups=album,single&limit=1", null, (c2, r2) => {
                    const x = c2 === 200 ? (r2?.items ?? [])[0] : null;
                    if (x) {
                        const tile = Catalog.albumTile(x);
                        tile.sub = a.name + (tile.year ? " • " + tile.year : "");
                        albums[i] = tile;
                    }
                    done();
                });
            });
        });
    }

    Component {
        id: procComp
        Process {
            id: p
            property string platform
            property var last: null
            stdout: SplitParser {
                onRead: line => {
                    let d = null;
                    try { d = JSON.parse(line); } catch (e) {}
                    if (!d) return;
                    p.last = d;
                    if (p.platform !== "spotify") root.put(p.platform, d);
                }
            }
            onExited: code => {
                if (p.platform === "spotify" && p.last) root.spotifyFill(p.last);
                else root.setBusy(p.platform, false);
                if (!p.last) root.put(p.platform, {});
                Qt.callLater(p.destroy);
            }
            property Timer watchdog: Timer {
                interval: 60000
                running: p.running
                onTriggered: p.running = false
            }
        }
    }
}
