# Design

## World: "listening room at night"

A dark room lit only by the record that is playing. The window is a sheet of smoked glass over the desktop; the current cover, blown up and blurred, is the light source behind it. Nothing in the UI owns a colour of its own: every hue comes from the cover's palette (`Player.accent`, `accent2`, `accent3`, `tint`).

Glass here is functional, not decoration: the compositor blur (ext-background-effect) lets the desktop show through, and the blurred cover tints it with the track's colours.

## Tokens

- Field: blurred cover at 0.55 opacity, then `tint` at 0.55. Text sits on this field, never on cards.
- Text: white at 1.0 (primary), 0.66 (secondary), 0.42 (tertiary / inactive lyrics). Never grey.
- Accent: `Player.accent` for the progress fill, the play button's glow and the active visualizer bars.
- Hairline: white at 0.10, 1px. Used only to separate the lyrics column and to edge the window.
- Radius: cover 18, buttons fully round, window corners left to Hyprland.
- Type: Adwaita Sans (Inter lineage, full Cyrillic) for the interface and the tall clock; Yeseva One for centre-stage lyrics and titles. Track title 24/600, artist 15/500, lyrics 26/700 active and 22/600 inactive, time 12/500 with tabular figures.
- Spacing scale: 4, 8, 12, 16, 24, 32, 48.

## Views

Two views share the clock, library and transport; switching moves and tilts them (520ms ease-out).

### Lyrics view (default)

Proportions of the window, not pixels:

- Centre stage: the current phrase in Yeseva One, centred in the window (stage ~38% wide, from 24% height down to the search field), type ~6% of the window height. Phrases are at most six words, as two rows of one to three. Words fly in from depth (blur, 3D rotation, scale 1.45 → 1, staggered), light up white as they are sung with a small pop, and burst towards the viewer when the next phrase arrives. Unsung words are the accent colour, lightened, at 55%.
- Seven letter-level animation styles (LyricStage.qml), all beat-reactive (bass level + kick pulses): fly (words from depth, burst towards the viewer), extrude (7-layer extrusion in the darkened accent, deeper on the bass; radial tumbling explosion on exit), crumble (letters drop in; fall under gravity in random order), wave (sine ride, amplitude from bass, jump on kicks), glitch (RGB split widening on kicks, sideways smear out), neon (flicker-on sign, accent glow pulsing with the bass, flicker-off), bounce (words drop with OutBounce, squash on kicks, fall out). "Auto" picks a different one for every phrase. Every style sits on a sphere projection: letters turn with the surface (Y by longitude, X by latitude), spacing shrinks by the same cosine, outer rows narrow like a drum, the centre swells by 14%; a thin three-layer depth gives all letters some relief.
- Without synced lyrics the track title takes the stage, the artist underneath.
- Pointer activity swaps the stage for a smaller cover carousel (≤26% of the window height); after 5s without movement the lyrics return (380ms crossfade).
- Left block at ~16% from the left edge, ~17% wide: the date, then a tall clock (Adwaita Sans Light, proportional figures, condensed to 80% and stretched ×2.1, tight tracking, translucent white with a hint of the accent; the panel overlaps the foot of the digits), then the library as floating rows (no glass sheet; the playing track is a raised glass card). Clock and list tilt 16° to face the stage.
- Search field and a compact transport bar (~36% wide) centred at the bottom; the bar holds the source dot, controls, a mini now-playing with a hairline progress, and the view toggles.

### Covers view



- Clock at the top centre of the free area, in the accent colour, date underneath (never above: no kicker labels).
- Cover carousel in the middle: recent history to the left, the playing track in the centre, the Spotify queue to the right. Cards are glass with a caption plate under the cover; side cards rotate away in 3D (up to 48°), shrink 13% per step and sink into the field. The cards ride a gentle arc: the centre one highest, the sides dropping (7.5% of a card per step, growing) and leaning along the curve (3° per step).
- Library panel on the left (glass, 320px): tabs Далее / История / Spotify.
- Lyrics column on the right (up to 400px), only when lyrics exist; otherwise the carousel takes the room. Without space for the column, the current line sits under the carousel.
- Transport bar at the bottom: a glass pill with the source picker, controls, progress, volume and view toggles.
- Under 900px wide the library becomes a drawer over a dimmed field. Under 280px tall the window becomes a mini row.

The source menu opens inside the window above the source pill. The product has no separate pop-up windows.

## Backdrop

Field, bottom to top: smoke, blurred cover, the sharp cover with a slow 60s zoom drift (when there is no clip; tint 30% over it), the music video (when found; muted, cropped to fill, 28% black over it), cover tint (22% over video, 60% without), glass and content. The video fades in over 900ms once frames arrive. The clip chip sits top-right and only appears on hover or while a clip is being looked up.

## Edge light

A 2.4px line of light (12% brighter than the first tuning; every parameter adjustable live from the glow menu) along a rounded rectangle (radius 14) just inside the screen edge, with a narrow inward halo. Two cover colours share the perimeter half and half; where they meet the light dims to 12% over a soft band, and the split turns around the screen every 14s while three bright streaks with fading tails run along the line at twice that speed. Bass brightens the line; the halo widens only slightly (kicks must not wash into the screen). A kick adds a short flash (max 0.7) that decays over 520ms and throws 2–7 sparks inwards from each edge segment, in the colour under that segment. If the cover's two colours are within 0.08 hue, the second becomes the neighbouring hue (+0.13). The light sits above bars and windows, and behind a fullscreen window on its workspace.

## Motion

- Carousel: spring-driven travel between cards (scroll, drag, click); drifts back to the playing track after 6s idle.
- The authored moment: a track change. The cover dissolves from blur 1 to 0 and scales 0.94 to 1 with an exponential ease-out over 700ms; the background field crossfades.
- Ambient: the cover breathes with the bass (scale up to +3%); the edge glow pulses with the bass and drifts around the screen over 24s.
- Lyrics scroll with an ease-out and the active line sweeps from left to right.

## Icons

Authored SVG paths on a 24px grid, filled, rounded joins (`Icon.qml`). No glyph fonts, no emoji.
