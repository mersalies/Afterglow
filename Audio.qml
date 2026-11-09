pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Reads spectrum data from cava (PipeWire input) while music is playing.
Singleton {
    id: root

    readonly property int bars: 24
    property var levels: new Array(bars).fill(0)
    // 0..1, low-frequency energy (drives glow pulses)
    property real bass: 0
    // 0..1, overall energy
    property real energy: 0
    // Kick detection: bass jumping well above its recent average.
    property real bassAvg: 0
    property double lastKick: 0
    signal kicked(real strength)

    readonly property bool wanted: Player.isPlaying
    readonly property string confPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/afterglow-cava.conf"

    readonly property string conf: [
        "[general]",
        "bars = " + bars,
        "framerate = 45",
        "autosens = 1",
        "lower_cutoff_freq = 40",
        "higher_cutoff_freq = 12000",
        "[input]",
        "method = pipewire",
        "source = auto",
        "[output]",
        "method = raw",
        "raw_target = /dev/stdout",
        "data_format = ascii",
        "ascii_max_range = 1000",
        "bar_delimiter = 59",
        "frame_delimiter = 10",
        "channels = mono",
        "mono_option = average",
        "[smoothing]",
        "noise_reduction = 55",
        ""
    ].join("\n")

    Process {
        id: cava
        running: root.wanted
        command: ["sh", "-c", 'printf "%s" "$1" > "$2" && exec cava -p "$2"', "sh", root.conf, root.confPath]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";");
                const lv = [];
                let sum = 0;
                for (let i = 0; i < root.bars && i < parts.length; i++) {
                    const v = (parseInt(parts[i]) || 0) / 1000;
                    lv.push(v);
                    sum += v;
                }
                if (lv.length < root.bars) return;
                root.levels = lv;
                root.energy = sum / lv.length;
                root.bass = (lv[0] + lv[1] + lv[2] + lv[3]) / 4;
                const now = Date.now();
                if (root.bass > root.bassAvg * 1.35 + 0.08 && now - root.lastKick > 180) {
                    root.lastKick = now;
                    root.kicked(Math.min(1, root.bass - root.bassAvg + 0.3));
                }
                root.bassAvg = root.bassAvg * 0.94 + root.bass * 0.06;
            }
        }
        onExited: {
            root.levels = new Array(root.bars).fill(0);
            root.bass = 0;
            root.energy = 0;
            if (root.wanted) restart.start();
        }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: if (root.wanted) cava.running = true
    }

    onWantedChanged: if (!wanted) {
        levels = new Array(bars).fill(0);
        bass = 0;
        energy = 0;
    }
}
