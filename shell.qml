//@ pragma UseQApplication
//@ pragma AppId afterglow
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    MainWindow {}

    Variants {
        model: Quickshell.screens
        Glow {}
    }

    // `afterglow ipc call afterglow <fn>`
    IpcHandler {
        target: "afterglow"
        function glow(): void { Config.glowEnabled = !Config.glowEnabled; }
        function lyrics(): void { Config.showLyrics = !Config.showLyrics; }
        function toggle(): void { Player.toggle(); }
        function next(): void { Player.next(); }
        function previous(): void { Player.previous(); }
    }
}
