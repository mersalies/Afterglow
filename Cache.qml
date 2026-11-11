pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Disk caches in ~/.cache/afterglow: music videos, track audio, cover art.
// Each folder is kept under its size limit from the settings (oldest files go
// first); usage is measured for the settings menu, and everything can be cleared.
Singleton {
    id: root

    readonly property string dir: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/afterglow"

    // MB in use, refreshed by measure()
    property real clipsMB: 0
    property real audioMB: 0
    property real artMB: 0

    function limitBytes(mb) { return Math.max(10, mb) * 1048576; }

    // Shell snippet: keep folder $1 under $2 bytes, newest files kept. For the
    // fetch scripts, which call it right after touching the file they use.
    readonly property string pruneFn:
        'prune() { t=0; ls -t "$1" 2>/dev/null | grep -v "\\.part$" | while read -r f; do ' +
        's=$(stat -c %s "$1/$f" 2>/dev/null || echo 0); t=$((t+s)); ' +
        '[ "$t" -gt "$2" ] && rm -f "$1/$f"; done; }; '

    function measure() {
        du.running = false;
        du.running = true;
    }

    Process {
        id: du
        command: ["sh", "-c", 'cd "$1" 2>/dev/null || exit 0; for d in clips audio art; do printf "%s %s\\n" "$d" "$(du -sb "$d" 2>/dev/null | cut -f1)"; done', "sh", root.dir]
        stdout: SplitParser {
            onRead: line => {
                const [name, bytes] = line.split(" ");
                const mb = (parseInt(bytes) || 0) / 1048576;
                if (name === "clips") root.clipsMB = mb;
                else if (name === "audio") root.audioMB = mb;
                else if (name === "art") root.artMB = mb;
            }
        }
    }

    // Apply the limits now (after the user lowers one), then re-measure.
    function prune() { pruner.running = false; pruner.running = true; }
    Process {
        id: pruner
        // Also sweeps downloads that were abandoned half-way (older than an hour).
        command: ["sh", "-c", root.pruneFn + 'find "$1/clips" "$1/audio" "$1/art" -name "*.part*" -mmin +60 -delete 2>/dev/null; '
                  + 'prune "$1/clips" "$2"; prune "$1/audio" "$3"; prune "$1/art" "$4"', "sh", root.dir,
                  String(root.limitBytes(Config.clipCacheMB)), String(root.limitBytes(Config.audioCacheMB)), String(root.limitBytes(Config.artCacheMB))]
        onExited: root.measure()
    }

    // Bring old caches under the limits once after start.
    Timer {
        running: true
        interval: 10000
        onTriggered: root.prune()
    }

    Timer {
        id: pruneLater
        interval: 800
        onTriggered: root.prune()
    }
    Connections {
        target: Config
        function onClipCacheMBChanged() { pruneLater.restart(); }
        function onAudioCacheMBChanged() { pruneLater.restart(); }
        function onArtCacheMBChanged() { pruneLater.restart(); }
    }

    // Remove every cached clip, audio file and cover (choices of clips are kept).
    // What is playing right now keeps working: the open files stay readable.
    function clear() { clearer.running = false; clearer.running = true; }
    Process {
        id: clearer
        command: ["sh", "-c", 'rm -rf "$1/clips" "$1/audio" "$1/art"; mkdir -p "$1/clips" "$1/audio" "$1/art"', "sh", root.dir]
        onExited: {
            root.measure();
            Spotify.say("Кэш очищен");
        }
    }
}
