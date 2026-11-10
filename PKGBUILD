# Local package: run `makepkg -si` in this directory.
pkgname=afterglow
pkgver=0.15.0
pkgrel=1
pkgdesc="Glass music companion for Hyprland: synced lyrics, ambient screen glow, any MPRIS player"
arch=('any')
license=('MIT' 'OFL-1.1')
depends=('quickshell' 'qt6-declarative' 'qt6-5compat' 'cava' 'curl' 'python' 'xdg-utils' 'adwaita-fonts' 'qt6-multimedia' 'qt6-multimedia-ffmpeg' 'yt-dlp')
makedepends=('qt6-shadertools')
optdepends=('playerctl: control playback from Hyprland keybinds'
            'spotifyd: play Spotify with the Spotify app closed')

build() {
    cd "$startdir/shaders"
    for f in edge bulge; do
        /usr/lib/qt6/bin/qsb --glsl "100es,120,150" --hlsl 50 --msl 12 -o $f.frag.qsb $f.frag
    done
}

package() {
    cd "$startdir"
    install -Dm644 -t "$pkgdir/usr/share/afterglow" ./*.qml
    install -Dm755 spotify-auth.py "$pkgdir/usr/share/afterglow/spotify-auth.py"
    install -Dm755 lyrics-ytm.py "$pkgdir/usr/share/afterglow/lyrics-ytm.py"
    install -Dm755 catalog.py "$pkgdir/usr/share/afterglow/catalog.py"
    install -Dm644 -t "$pkgdir/usr/share/afterglow/fonts" fonts/YesevaOne-Regular.ttf
    install -Dm644 -t "$pkgdir/usr/share/afterglow/shaders" shaders/edge.frag.qsb shaders/bulge.frag.qsb
    install -Dm644 fonts/OFL.txt "$pkgdir/usr/share/licenses/$pkgname/OFL-YesevaOne.txt"
    install -Dm755 dist/afterglow "$pkgdir/usr/bin/afterglow"
    install -Dm644 dist/afterglow.desktop "$pkgdir/usr/share/applications/afterglow.desktop"
    install -Dm644 dist/afterglow.svg "$pkgdir/usr/share/icons/hicolor/scalable/apps/afterglow.svg"
    install -Dm644 dist/afterglow.service "$pkgdir/usr/lib/systemd/user/afterglow.service"
    install -Dm644 dist/spotifyd.conf "$pkgdir/usr/share/afterglow/spotifyd.conf"
}
