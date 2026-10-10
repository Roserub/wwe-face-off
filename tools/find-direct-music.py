"""Collect public audio-download candidates for manual title/artist review."""
import concurrent.futures
import csv
import html
import json
import re
import unicodedata
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def slug(text):
    return re.sub('[^a-z0-9]+', '-', unicodedata.normalize('NFD', text).encode('ascii', 'ignore').decode().lower()).strip('-')


def search(item):
    key, name = item
    url = 'https://s-' + slug(name) + '.mp3.pm/'
    try:
        with urllib.request.urlopen(url, timeout=20) as response:
            source = response.geturl()
            text = response.read().decode('utf-8')
        songs = []
        for block in re.findall(r'<li class="cplayer-sound-item".*?</li>', text, re.S):
            get = lambda pattern: html.unescape(re.search(pattern, block, re.S)[1])
            songs.append({'title':get(r'class="cplayer-data-sound-title">(.*?)</b>'),
                          'artist':get(r'class="cplayer-data-sound-author">(.*?)</i>'),
                          'duration':get(r'class="cplayer-data-sound-time">(.*?)</em>'),
                          'url':get(r'data-download-url="([^"]+)"'), 'source':source})
        return key, songs
    except Exception as error:
        return key, {'error':str(error)}


if __name__ == '__main__':
    themes = json.loads((ROOT/'themes.js').read_text(encoding='utf-8-sig').split('window.THEMES = ',1)[1].strip().rstrip(';'))
    rows = csv.DictReader((ROOT/'roster.csv').open(encoding='utf-8-sig'))
    targets = [(slug(r['name']),r['name']) for r in rows if slug(r['name']) not in themes]
    # These three used YouTube as an explicit override previously.
    targets += [('liv-morgan','Liv Morgan')]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        data = dict(pool.map(search, targets))
    (ROOT/'tools/direct-candidates.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'{len(data)} searches saved for review')
