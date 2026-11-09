# Product

<!-- impeccable:product-schema 1 -->

## Platform

Linux desktop: Arch Linux, Hyprland (Wayland). Not web, not mobile.

## Stack

Quickshell 0.3 (QML / Qt 6.12), packaged with a PKGBUILD. Chosen because the user already runs Quickshell for their shell; delegated to Claude.

## Users

A single user, the owner of this machine: listens to music all day on an Arch + Hyprland desktop and wants playback to be a visual part of the desktop.

## Product Purpose

Afterglow is a companion app for whatever music is already playing. It does not stream or store music. It reads the current track over MPRIS and shows it as a full application window with cover art, controls and synced lyrics, and lights the screen edges with the cover's colours in time with the music.

## Positioning

An original Linux app in the spirit of iBaila (glass player, ambient edge light, karaoke lyrics). It must not copy iBaila's name, layout, icons or assets.

## Operating Context

- Sources (confirmed): the Spotify app, the Yandex Music app, VK Music and other sites in the browser. Anything that exposes MPRIS works.
- It runs as a normal application window (user: "a full app with no pop-up windows"). It can be tiled, floated or resized by Hyprland like any other window.
- The edge glow is a click-through layer and never takes input.

## Capabilities and Constraints

- Track info and control: MPRIS (play/pause, previous/next, seek, volume when the player supports it).
- Afterglow's own cross-service queue: Spotify tracks play in Spotify, YouTube / YouTube Music / SoundCloud tracks play in Afterglow's built-in player (yt-dlp + Qt Multimedia); the next track starts by itself. VK and Yandex Music need an account for full tracks, so they are not first-class sources.
- Colours: quantized from the cover art.
- Beat reaction: cava reading PipeWire.
- Lyrics: LRCLIB (free, no account). Coverage for Russian tracks is partial; the empty state has to be honest about it.
- Animated covers from Spotify Canvas / Apple Music are not available; motion is generated from the static cover.
- Undecided: whether the window should autostart.

## Brand Commitments

Name: Afterglow (confirmed by the user).

## Product Principles

1. The music is the content: cover and lyrics lead, chrome stays out of the way.
2. One window, no pop-ups.
3. Light follows the track: every colour comes from the current cover.
4. Works with any player, never asks for an account.
