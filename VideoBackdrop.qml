import QtQuick
import QtMultimedia
import QtQuick.Effects

// The current track's music video, muted and cropped to fill the window. Follows
// the player: plays and pauses with it and is nudged back when it drifts more than
// 1.5 s from the track position. Clips that cannot follow the track just loop.
Item {
    id: root

    readonly property bool wanted: Config.videoBackground && Clip.streamUrl !== ""

    // The video player (and FFmpeg behind it, ~70 MB) exists only while there is
    // a clip to show.
    readonly property var media: player.item?.media ?? null
    readonly property bool showing: media !== null && media.position > 300
        && (media.playbackState === MediaPlayer.PlayingState || !Player.isPlaying)

    opacity: showing ? Config.backdropOpacity : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.OutCubic } }

    Loader {
        id: player
        anchors.fill: parent
        active: root.wanted
        sourceComponent: Item {
            property alias media: mp

            // No audioOutput: the video stays silent.
            MediaPlayer {
                id: mp
                source: Clip.streamUrl
                videoOutput: output
                loops: Clip.synced ? 1 : MediaPlayer.Infinite
                onMediaStatusChanged: {
                    if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) root.follow(true);
                }
                onErrorOccurred: (error, message) => console.warn("Afterglow clip:", message)
            }

            VideoOutput {
                id: output
                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop

                // The default (0.1) only softens the cover; blur the video from 0.12 up.
                layer.enabled: Config.backdropBlur > 0.12
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: Math.min(1, Config.backdropBlur)
                    blurMax: 64
                    autoPaddingEnabled: false
                }
            }
        }
    }

    // Keep text readable over bright footage.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.28
    }

    function follow(force) {
        const media = root.media;
        if (!wanted || !media) return;
        if (Player.isPlaying) {
            if (media.playbackState !== MediaPlayer.PlayingState) media.play();
        } else if (media.playbackState === MediaPlayer.PlayingState) {
            media.pause();
        }
        if (Clip.synced && media.seekable) {
            const target = Math.max(0, (Player.position + Config.clipOffset) * 1000);
            if (force || Math.abs(media.position - target) > 1500) media.position = target;
        }
    }

    Connections {
        target: Player
        function onIsPlayingChanged() { root.follow(false); }
    }

    Timer {
        running: root.wanted
        interval: 1000
        repeat: true
        onTriggered: root.follow(false)
    }
}
