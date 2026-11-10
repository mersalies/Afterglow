#!/usr/bin/env python3
"""Lyrics from YouTube Music for Afterglow.

    lyrics-ytm.py ARTIST TITLE [DURATION_SECONDS]

Prints LRC ("[mm:ss.xx]line") when YouTube Music has timed lyrics, plain text
otherwise, nothing when the song or its lyrics are not found. Uses the same
unofficial endpoints as the YouTube Music app, so it may stop working when
YouTube changes them. Standard library only.
"""
import json
import re
import sys
import unicodedata
import urllib.request

# The web client's search results are simpler to read; only the Android client
# gets timed lyrics.
WEB = ({"clientName": "WEB_REMIX", "clientVersion": "1.20251015.01.00", "hl": "ru"},
       "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0")
ANDROID = ({"clientName": "ANDROID_MUSIC", "clientVersion": "7.27.52",
            "androidSdkVersion": 30, "hl": "ru"},
           "com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 11) gzip")
SONGS_ONLY = "EgWKAQIIAWoMEA4QChADEAQQCRAF"


def call(endpoint, body, client=ANDROID):
    body["context"] = {"client": client[0]}
    req = urllib.request.Request(
        "https://music.youtube.com/youtubei/v1/" + endpoint + "?prettyPrint=false",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": client[1]})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


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


def norm(s):
    s = unicodedata.normalize("NFKC", s).casefold().replace("ё", "е")
    return re.sub(r"[^\w]+", "", s)


def candidates(data):
    """(videoId, all visible text of the result row) for each song row."""
    for row in find(data, "musicResponsiveListItemRenderer"):
        vid = next(find(row, "videoId"), None)
        if vid:
            yield vid, norm(" ".join(runs(c) for c in find(row, "text")))


def matches(text, artist, title):
    first = re.split(r"/|,|&| feat\.?| ft\.?| x ", artist, flags=re.I)[0]
    clean = re.sub(r"\s*[\(\[].*?[\)\]]|\s+-\s+.*$|\s+feat\..*$", "", title, flags=re.I)
    return norm(first) in text and norm(clean) in text


def lrc_time(ms):
    s = ms / 1000
    return "[%02d:%05.2f]" % (s // 60, s % 60)


def main():
    if len(sys.argv) < 3:
        sys.exit(2)
    artist, title = sys.argv[1], sys.argv[2]
    found = call("search", {"query": artist + " " + title, "params": SONGS_ONLY}, WEB)
    vid = next((v for v, text in candidates(found) if matches(text, artist, title)), None)
    if not vid:
        return
    nxt = call("next", {"videoId": vid})
    browse = None
    for tab in find(nxt, "tabRenderer"):
        bid = tab.get("endpoint", {}).get("browseEndpoint", {}).get("browseId", "")
        if bid.startswith("MPLY"):
            browse = bid
    if not browse:
        return
    page = call("browse", {"browseId": browse})

    timed = next(find(page, "timedLyricsData"), None)
    if timed:
        out = []
        for line in timed:
            start = (line.get("cueRange") or {}).get("startTimeMilliseconds")
            text = line.get("lyricLine", "")
            if start is not None and text and text != "♪":
                out.append(lrc_time(int(start)) + text)
        if out:
            print("\n".join(out))
            return

    for desc in find(call("browse", {"browseId": browse}, WEB), "description"):
        text = runs(desc) if isinstance(desc, dict) else str(desc)
        if text.strip():
            print(text.strip())
            return


if __name__ == "__main__":
    try:
        main()
    except Exception as e:  # network or format change: just no lyrics
        print("lyrics-ytm:", e, file=sys.stderr)
        sys.exit(1)
