#!/usr/bin/env python3
"""Artist / album / track search for Afterglow's search panel.

    catalog.py search  PLATFORM QUERY      -> {"artist", "albums", "tracks"}
    catalog.py album   PLATFORM ID         -> {"title", "artist", "art", "sub", "tracks"}
    catalog.py library soundcloud USER     -> {"tracks", "sets"} (likes and playlists)

PLATFORM: youtube-music (the YouTube Music app's own endpoints, unofficial),
soundcloud and youtube (through yt-dlp). Prints one JSON object per line: a
slow search prints what it has first (SoundCloud: the artist and songs, then
again with the albums), the last line is the whole result. On failure an empty
result and a message on stderr. Spotify is searched in Spotify.qml.
"""
import json
import os
import re
import subprocess
import sys
import unicodedata
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor

UA = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"


def emit(d):
    print(json.dumps(d, ensure_ascii=False), flush=True)


# Covers and authors of SoundCloud pages, kept between runs: the library asks
# for dozens at every start, and SoundCloud turns away a burst of them.
META_FILE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "afterglow", "soundcloud.json")
try:
    with open(META_FILE) as f:
        META = json.load(f)
except Exception:
    META = {}
META_NEW = False


def save_meta():
    if not META_NEW:
        return
    try:
        os.makedirs(os.path.dirname(META_FILE), exist_ok=True)
        with open(META_FILE + ".tmp", "w") as f:
            json.dump(META, f, ensure_ascii=False)
        os.replace(META_FILE + ".tmp", META_FILE)
    except OSError:
        pass

# ----------------------------------------------------------------- helpers

def norm(s):
    s = unicodedata.normalize("NFKC", s or "").casefold().replace("ё", "е")
    return re.sub(r"[^\w]+", "", s)


def find(obj, key):
    if isinstance(obj, dict):
        if key in obj:
            yield obj[key]
        for v in obj.values():
            yield from find(v, key)
    elif isinstance(obj, list):
        for v in obj:
            yield from find(v, key)


def runs(obj):
    if isinstance(obj, str):
        return obj
    return "".join(r.get("text", "") for r in (obj or {}).get("runs", []))


def seconds(text):
    if not re.fullmatch(r"\d+(:\d\d){1,2}", text or ""):
        return 0
    total = 0
    for part in text.split(":"):
        total = total * 60 + int(part)
    return total


def big_thumb(obj, size=544):
    thumbs = next(find(obj, "thumbnails"), None) or []
    if not thumbs:
        return ""
    url = thumbs[-1].get("url", "")
    # googleusercontent images take their size in the URL
    return re.sub(r"=w\d+-h\d+.*$", "=w%d-h%d-l90-rj" % (size, size), url)


# ----------------------------------------------------------- YouTube Music

YTM = {"clientName": "WEB_REMIX", "clientVersion": "1.20251015.01.00", "hl": "ru"}
SONGS = "EgWKAQIIAWoMEA4QChADEAQQCRAF"
ALBUMS = "EgWKAQIYAWoMEA4QChADEAQQCRAF"
ARTISTS = "EgWKAQIgAWoMEA4QChADEAQQCRAF"


def ytm(endpoint, body):
    body["context"] = {"client": YTM}
    req = urllib.request.Request(
        "https://music.youtube.com/youtubei/v1/" + endpoint + "?prettyPrint=false",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": UA})
    # A stalled connection is retried once instead of waiting it out.
    for attempt in (0, 1):
        try:
            with urllib.request.urlopen(req, timeout=7) as r:
                return json.load(r)
        except OSError:
            if attempt:
                raise


def ytm_row(row, album=None):
    """A song row (search results, top songs, album tracks) -> track."""
    cols = [c.get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {})
            for c in row.get("flexColumns", [])]
    vid = (row.get("playlistItemData") or {}).get("videoId") or next(find(row, "videoId"), None)
    if not vid or not cols:
        return None
    title = runs(cols[0])
    artists, album_name, length = [], "", 0
    for col in cols[1:]:
        for r in col.get("runs", []):
            bid = next(find(r.get("navigationEndpoint", {}), "browseId"), "")
            if bid.startswith("UC"):
                artists.append(r["text"])
            elif bid.startswith("MPREb"):
                album_name = r["text"]
            elif seconds(r.get("text", "")):
                length = seconds(r["text"])
    for c in row.get("fixedColumns", []):
        length = length or seconds(runs(c.get("musicResponsiveListItemFixedColumnRenderer", {}).get("text")))
    if not artists and len(cols) > 1:
        first = (cols[1].get("runs") or [{}])[0].get("text", "")
        if first and first not in ("Песня", "Song", "Видео", "Video"):
            artists = [first]
    return {
        "title": title,
        "artist": ", ".join(artists) or (album or {}).get("artist", ""),
        "album": album_name or (album or {}).get("title", ""),
        "art": big_thumb(row.get("thumbnail", {}), 226) or (album or {}).get("art", "")
               or "https://i.ytimg.com/vi/%s/hqdefault.jpg" % vid,
        "uri": "https://music.youtube.com/watch?v=" + vid,
        "source": "youtube-music",
        "length": length,
    }


def ytm_rows(data, album=None, limit=50):
    out = []
    for row in find(data, "musicResponsiveListItemRenderer"):
        t = ytm_row(row, album)
        if t:
            out.append(t)
        if len(out) >= limit:
            break
    return out


def ytm_tile(item):
    """An album / single tile from a carousel or the albums search."""
    r = item.get("musicTwoRowItemRenderer")
    if r:
        bid = next(find(r.get("navigationEndpoint", {}), "browseId"), "")
        sub = runs(r.get("subtitle"))
        title = runs(r.get("title"))
        art = big_thumb(r.get("thumbnailRenderer", {}), 400)
    else:
        r = item.get("musicResponsiveListItemRenderer") or {}
        bid = next(find(r.get("navigationEndpoint", {}), "browseId"), "")
        cols = [c.get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}) for c in r.get("flexColumns", [])]
        title = runs(cols[0]) if cols else ""
        sub = runs(cols[1]) if len(cols) > 1 else ""
        art = big_thumb(r.get("thumbnail", {}), 400)
    if not bid.startswith("MPREb"):
        return None
    m = re.search(r"\b(?:19|20)\d\d\b", sub)
    year = m.group(0) if m else ""
    return {"id": bid, "title": title, "sub": sub, "art": art, "year": year, "platform": "youtube-music"}


def audience(text):
    """ "1,2 млн подписчиков" / "350 тыс." / "1.2M subscribers" -> a number."""
    m = re.search(r"([\d.,]+)\s*(млрд|млн|тыс|[KMB])?", text.replace("\xa0", " "))
    if not m:
        return 0
    n = float(m.group(1).replace(",", ".")) if m.group(1).count(",") + m.group(1).count(".") <= 1 else 0
    return n * {"тыс": 1e3, "K": 1e3, "млн": 1e6, "M": 1e6, "млрд": 1e9, "B": 1e9}.get(m.group(2), 1)


def ytm_search(q):
    nq = norm(q)
    artist = None
    # The three searches at once; songs and albums are only used without an artist.
    pool = ThreadPoolExecutor(3)
    f_artists = pool.submit(ytm, "search", {"query": q, "params": ARTISTS})
    f_songs = pool.submit(ytm, "search", {"query": q, "params": SONGS})
    f_albums = pool.submit(ytm, "search", {"query": q, "params": ALBUMS})
    pool.shutdown(wait=False)
    # Artists named exactly like the query (or containing it); the same name often
    # has several channels, so the one with the most subscribers wins.
    best = -1
    found = f_artists.result()
    for row in list(find(found, "musicResponsiveListItemRenderer"))[:6]:
        bid = next(find(row.get("navigationEndpoint", {}), "browseId"), "")
        cols = [c.get("musicResponsiveListItemFlexColumnRenderer", {}).get("text", {}) for c in row.get("flexColumns", [])]
        name = runs(cols[0]) if cols else ""
        if not bid.startswith("UC") or not norm(name):
            continue
        if not (norm(name) == nq or (len(nq) > 2 and nq in norm(name))):
            continue
        fans = audience(runs(cols[1]) if len(cols) > 1 else "") + (1 if norm(name) == nq else 0)
        if fans > best:
            best, artist = fans, {"id": bid, "name": name}

    if artist:
        page = ytm("browse", {"browseId": artist["id"]})
        head = next(find(page, "musicImmersiveHeaderRenderer"), None) or next(find(page, "musicVisualHeaderRenderer"), None) or {}
        artist["image"] = big_thumb(head.get("thumbnail", {}), 900)
        artist["about"] = runs(head.get("description"))[:400]
        artist["sub"] = runs(head.get("monthlyListenerCount"))
        tracks = []
        for shelf in find(page, "musicShelfRenderer"):
            tracks = [t for t in (ytm_row(c.get("musicResponsiveListItemRenderer", {})) for c in shelf.get("contents", [])) if t]
            more = next(find(shelf.get("bottomEndpoint", {}), "browseId"), "") or \
                next(find(shelf.get("title", {}), "browseId"), "")
            if more and len(tracks) < 10:
                try:
                    tracks = ytm_rows(ytm("browse", {"browseId": more}), limit=10) or tracks
                except Exception:
                    pass
            break
        albums = []
        for car in find(page, "musicCarouselShelfRenderer"):
            tiles = [t for t in (ytm_tile(i) for i in car.get("contents", [])) if t]
            albums += tiles
        seen, uniq = set(), []
        for a in albums:
            if a["id"] not in seen:
                seen.add(a["id"])
                uniq.append(a)
        return {"artist": artist, "albums": uniq[:16], "tracks": tracks[:10]}

    songs = ytm_rows(f_songs.result(), limit=10)
    albums = [t for t in (ytm_tile({"musicResponsiveListItemRenderer": r})
                          for r in find(f_albums.result(), "musicResponsiveListItemRenderer")) if t]
    return {"artist": None, "albums": albums[:12], "tracks": songs}


def ytm_album(bid):
    page = ytm("browse", {"browseId": bid})
    head = next(find(page, "musicResponsiveHeaderRenderer"), None) or next(find(page, "musicDetailHeaderRenderer"), None) or {}
    album = {
        "title": runs(head.get("title")),
        "artist": runs(head.get("straplineTextOne")),
        "sub": runs(head.get("subtitle")),
        "about": runs(next(find(head.get("description", {}), "description"), None))[:400] if head.get("description") else "",
        "art": big_thumb(head.get("thumbnail", {}), 800),
    }
    album["tracks"] = ytm_rows(page, album, limit=100)
    return album


# ------------------------------------------------- SoundCloud, YouTube (yt-dlp)

def ytdlp(*args):
    out = subprocess.run(["yt-dlp", "--no-warnings", "--flat-playlist", "-J", *args],
                         capture_output=True, text=True, timeout=60)
    return json.loads(out.stdout) if out.returncode == 0 and out.stdout else {}


def split_title(raw, who):
    t = re.sub(r"\s*[\(\[](official|офиц|music video|lyric|audio|video|клип|hd|4k|mv)[^\)\]]*[\)\]]", "", raw or "", flags=re.I).strip()
    m = re.match(r"^(.+?)\s+[-–—]\s+(.+)$", t)
    if m:
        return m.group(1).strip(), m.group(2).strip()
    return re.sub(r"\s*-\s*Topic$|VEVO$", "", who or "", flags=re.I).strip(), t


def entry_track(e, source):
    url = e.get("webpage_url") or e.get("url") or ""
    if source == "youtube" and e.get("id"):
        url = "https://www.youtube.com/watch?v=" + e["id"]
    if not url:
        return None
    who = e.get("artist") or e.get("uploader") or e.get("channel") or ""
    artist, title = (who, e["track"]) if e.get("track") else split_title(e.get("title"), who)
    if source == "soundcloud":
        artist = who or artist
        title = e.get("title") or title
    thumbs = e.get("thumbnails") or []
    art = ("https://i.ytimg.com/vi/%s/hqdefault.jpg" % e["id"]) if source == "youtube" and e.get("id") else \
        next((t["url"] for t in thumbs if t.get("id") == "t500x500"), thumbs[-1]["url"] if thumbs else "")
    return {"title": title, "artist": artist, "album": "", "art": art, "uri": url,
            "source": source, "length": e.get("duration") or 0}


def sc_oembed(url, deep=False):
    """Cover and author of a SoundCloud page (track, set, profile): from the cache,
    else its public oEmbed; `deep` falls back to yt-dlp (for sets) when that fails."""
    global META_NEW
    if url in META:
        return META[url]["art"], META[url]["author"]
    art, author = "", ""
    try:
        req = urllib.request.Request("https://soundcloud.com/oembed?format=json&url=" + urllib.parse.quote(url, safe=""),
                                     headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=6) as r:
            d = json.load(r)
        art, author = d.get("thumbnail_url") or "", d.get("author_name") or ""
    except Exception:
        if not deep:
            return "", ""
        d = ytdlp("--playlist-items", "0", url)
        if not d:
            return "", ""
        art = next((t["url"] for t in d.get("thumbnails") or [] if t.get("id") == "t500x500"), "")
        author = d.get("uploader") or ""
    art = "" if "placeholder" in art else art
    META[url] = {"art": art, "author": author}
    META_NEW = True
    return art, author


def sc_art(url):
    return sc_oembed(url)[0]


def sc_fill_art(items, key, who=None, deep=False):
    """Covers for the items without one, fetched side by side; `who` also takes
    the author's name into that field."""
    need = [x for x in items if not x.get("art") and x.get(key)]
    with ThreadPoolExecutor(8) as ex:
        for x, (art, author) in zip(need, ex.map(lambda x: sc_oembed(x[key], deep), need)):
            x["art"] = art
            if who and author:
                x[who] = author


def sc_search(q):
    data = ytdlp("scsearch10:" + q)
    entries = data.get("entries") or []
    tracks = [t for t in (entry_track(e, "soundcloud") for e in entries) if t]
    nq = norm(q)
    artist, albums = None, []
    for e in entries:
        who = e.get("uploader") or ""
        if who and (norm(who) == nq or (len(nq) > 2 and nq in norm(who))):
            art = next((t["url"] for t in (e.get("thumbnails") or []) if t.get("id") == "t500x500"), "")
            artist = {"id": e.get("uploader_url", ""), "name": who, "image": art, "sub": "SoundCloud", "about": ""}
            break
    if artist and artist["id"]:
        mine = [t for t in tracks if t["artist"] == artist["name"]]
        tracks = mine + [t for t in tracks if t["artist"] != artist["name"]]
        # The artist and songs show while the albums load (another yt-dlp run).
        emit({"artist": artist, "albums": [], "tracks": tracks[:10]})
        sets = ytdlp(artist["id"] + "/albums").get("entries") or []
        albums = [{"id": s["url"], "title": s.get("title") or "", "sub": "Альбом", "art": "", "year": "",
                   "platform": "soundcloud"} for s in sets if s.get("url")][:16]
        sc_fill_art(albums, "id")
    sc_fill_art(tracks[:10], "uri")
    return {"artist": artist, "albums": albums, "tracks": tracks[:10]}


def sc_track(url):
    """One track from its link: from oEmbed when it is a page (quick); through
    yt-dlp when it is an API link (only an id) or oEmbed does not answer."""
    if "//soundcloud.com/" in url or "//www.soundcloud.com/" in url:
        try:
            req = urllib.request.Request("https://soundcloud.com/oembed?format=json&url=" + urllib.parse.quote(url, safe=""),
                                         headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=6) as r:
                d = json.load(r)
            who = d.get("author_name") or ""
            title = d.get("title") or ""
            if who and title.endswith(" by " + who):
                title = title[:-len(" by " + who)]
            art = d.get("thumbnail_url") or ""
            return {"title": title, "artist": who, "album": "", "art": "" if "placeholder" in art else art,
                    "uri": url, "source": "soundcloud", "length": 0}
        except Exception:
            pass
    try:
        out = subprocess.run(["yt-dlp", "--no-warnings", "-J", "--skip-download", url],
                             capture_output=True, text=True, timeout=40)
        return entry_track(json.loads(out.stdout), "soundcloud") if out.returncode == 0 else None
    except Exception:
        return None


def sc_album(url):
    # The flat list of a set holds only links: tracks with a page link come from
    # oEmbed at once; those with an API link (only an id) are looked up after,
    # and the album is printed again with them.
    data = ytdlp(url)
    art = sc_art(url)
    links = [(e.get("url") or "").split("?")[0] for e in data.get("entries") or []]
    links = [u for u in links if u]
    found = {}

    def result():
        tracks = [found[u] for u in links if found.get(u)]
        for t in tracks:
            t["album"] = data.get("title") or ""
            t["art"] = t["art"] or art
        return {"title": data.get("title") or "", "artist": data.get("uploader") or "", "sub": "SoundCloud",
                "about": "", "art": art, "tracks": tracks}

    pages = [u for u in links if "//soundcloud.com/" in u or "//www.soundcloud.com/" in u]
    api = [u for u in links if u not in pages]
    with ThreadPoolExecutor(8) as ex:
        for u, t in zip(pages, ex.map(sc_track, pages)):
            found[u] = t
        if api:
            emit(dict(result(), more=True))
            for u, t in zip(api, ex.map(sc_track, api)):
                found[u] = t
    return result()


def sc_library(user):
    """A public profile's liked tracks and its playlists: its own sets and the
    sets it liked. Printed twice: at once, then again with the covers."""
    with ThreadPoolExecutor(2) as ex:
        likes, own = ex.map(lambda path: ytdlp("--playlist-items", "1:300", "https://soundcloud.com/%s/%s" % (user, path)),
                            ("likes", "sets"))
    tracks, sets, seen = [], [], set()
    for e in (own.get("entries") or []) + (likes.get("entries") or []):
        url = (e.get("url") or "").split("?")[0]
        m = re.search(r"//(?:www\.)?soundcloud\.com/([^/]+)/", url)
        if not m or url in seen:
            continue
        seen.add(url)
        who = e.get("uploader") or m.group(1).replace("-", " ").replace("_", " ").title()
        if "/sets/" in url:
            sets.append({"id": url, "title": e.get("title") or "", "sub": who, "art": "", "uri": url,
                         "mine": m.group(1).lower() == user.lower()})
        else:
            tracks.append({"title": e.get("title") or "", "artist": who, "album": "", "art": "", "uri": url,
                           "source": "soundcloud", "length": e.get("duration") or 0})
    # What the cache knows already goes into the first answer.
    for x, key, who in [(x, "id", "sub") for x in sets] + [(x, "uri", "artist") for x in tracks]:
        if x[key] in META:
            x["art"], x[who] = META[x[key]]["art"], META[x[key]]["author"] or x[who]
    emit({"tracks": tracks, "sets": sets})
    sc_fill_art(sets, "id", "sub", deep=True)
    sc_fill_art(tracks[:150], "uri", "artist")
    # The same album liked twice under two links shows once.
    named = set()
    sets = [x for x in sets if (x["title"].lower(), x["sub"]) not in named and not named.add((x["title"].lower(), x["sub"]))]
    return {"tracks": tracks, "sets": sets}


def yt_search(q):
    data = ytdlp("ytsearch15:" + q)
    tracks = [t for t in (entry_track(e, "youtube") for e in data.get("entries") or []) if t]
    return {"artist": None, "albums": [], "tracks": tracks}


# --------------------------------------------------------------------- main

def main():
    if len(sys.argv) < 4:
        sys.exit(2)
    what, platform, arg = sys.argv[1], sys.argv[2], sys.argv[3]
    fn = {
        ("search", "youtube-music"): ytm_search,
        ("album", "youtube-music"): ytm_album,
        ("search", "soundcloud"): sc_search,
        ("album", "soundcloud"): sc_album,
        ("search", "youtube"): yt_search,
        ("library", "soundcloud"): sc_library,
    }.get((what, platform))
    if not fn:
        sys.exit(2)
    emit(fn(arg))
    save_meta()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("catalog:", e, file=sys.stderr)
        print(json.dumps({"artist": None, "albums": [], "tracks": []}))
        sys.exit(1)
