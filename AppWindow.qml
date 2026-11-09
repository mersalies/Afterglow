pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Where the Afterglow window is in Hyprland: which monitor, and whether its
// workspace is currently shown. The edge glow follows it.
Singleton {
    id: root

    readonly property bool hyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""

    readonly property HyprlandToplevel toplevel: hyprland
        ? Hyprland.toplevels.values.find(t => (t.wayland?.appId ?? t.lastIpcObject?.class ?? "") === "afterglow") ?? null
        : null

    // A fullscreen window on our workspace: the glow should step behind it.
    readonly property bool fullscreenHere: toplevel?.workspace?.hasFullscreen ?? false

    readonly property string monitorName: toplevel?.monitor?.name ?? ""
    // Shown if its workspace is the monitor's active one. When Hyprland has not told
    // us the workspace yet, assume visible rather than leaving the glow dark.
    readonly property bool visibleNow: {
        const ws = toplevel?.workspace;
        const activeWs = toplevel?.monitor?.activeWorkspace;
        if (!ws || !activeWs) return true;
        return ws.id === activeWs.id || ws.active;
    }

    // Should the glow be drawn on this screen?
    function glowsOn(screen) {
        if (!Config.glowFollowsWindow || !hyprland) return true;
        return toplevel !== null && visibleNow && monitorName === screen.name;
    }

    // The toplevel list may not know our window's class, or its workspace, until Hyprland is asked.
    Timer {
        running: root.hyprland && (root.toplevel === null || !root.toplevel.workspace || !root.toplevel.monitor)
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshMonitors();
            Hyprland.refreshToplevels();
        }
    }
}
