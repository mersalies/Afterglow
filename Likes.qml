pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The heart button. A Spotify track goes into Spotify's own "Liked Songs"
// (Web API). SoundCloud, Apple Music, Yandex, VK and YouTube give no way to
// like a track from outside, so their tracks are kept in Afterglow's own list
// (~/.local/share/afterglow/liked.json), shown in the library of that service.
Singleton {
    id: root

    // [{ title, artist, album, art, uri, source, at }]
    property alias tracks: adapter.tracks

    readonly property bool viaSpotify: Player.source === "spotify" && Spotify.connected && Player.trackUri.startsWith("spotify:track:")
    function same(t) { return (t.uri && t.uri === Player.trackUri) || (t.title === Player.title && t.artist === Player.artist); }
    // Is the playing track liked?
    readonly property bool current: Player.title !== ""
        && (viaSpotify ? Spotify.liked.some(t => t.uri === Player.trackUri) : tracks.some(same))
    readonly property string hint: current ? "Убрать из любимых"
        : viaSpotify ? "В любимые треки Spotify" : "В любимые Afterglow (" + Player.sourceName(Player.source, null) + ")"

    function of(source) { return tracks.filter(t => t.source === source); }

    function toggle() {
        if (Player.title === "") return;
        const t = { title: Player.title, artist: Player.artist, album: Player.album, art: Player.localArt || Player.artUrl,
                    uri: Player.trackUri, source: Player.source, length: Player.length, at: Date.now() };
        if (viaSpotify) { Spotify.setLiked(t, !current); return; }
        if (current) {
            tracks = tracks.filter(x => !same(x));
            Spotify.say("Убрано из любимых");
        } else {
            tracks = [t].concat(tracks);
            Spotify.say("В любимых Afterglow: " + t.title);
        }
    }

    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/afterglow"
    FileView {
        id: file
        path: root.dir + "/liked.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) mkdir.running = true; }
        JsonAdapter {
            id: adapter
            property var tracks: []
        }
    }
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: file.writeAdapter()
    }
}
