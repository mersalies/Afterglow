pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Everything that played, newest first, kept in ~/.local/share/afterglow/history.json.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/afterglow"
    readonly property int limit: 200

    // [{ title, artist, album, art, uri, source, at }]
    property alias tracks: adapter.tracks

    readonly property string key: Player.title !== "" ? Player.artist + "\u0001" + Player.title : ""
    onKeyChanged: settle.restart()

    // Players flicker through intermediate metadata on skip; record once it settles.
    Timer {
        id: settle
        interval: 2500
        onTriggered: root.record()
    }

    Connections {
        target: Player
        function onLocalArtChanged() {
            const t = root.tracks[0];
            if (t && Player.localArt && t.title === Player.title && t.artist === Player.artist && t.art !== Player.localArt) {
                const next = root.tracks.slice();
                next[0] = Object.assign({}, t, { art: Player.localArt });
                root.tracks = next;
            }
        }
    }

    function same(a, b) { return a.title === b.title && a.artist === b.artist; }

    function record() {
        if (key === "") return;
        const entry = {
            title: Player.title,
            artist: Player.artist,
            album: Player.album,
            art: Player.localArt || Player.artUrl,
            uri: Player.trackUri,
            source: Player.source,
            at: Date.now()
        };
        const rest = tracks.filter(t => !same(t, entry));
        tracks = [entry].concat(rest).slice(0, limit);
    }

    // Replay a remembered track: Spotify tracks in Spotify, the rest in Afterglow.
    function play(t) {
        if (t?.uri) Queue.playNow(t);
    }

    function clear() { tracks = []; }

    FileView {
        id: file
        path: root.dir + "/history.json"
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) mkdir.running = true;
        }

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
