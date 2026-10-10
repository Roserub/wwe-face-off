"""Build reviewed 30-second local MP3 clips. Requires imageio-ffmpeg."""
import concurrent.futures
import hashlib
import json
import os
import subprocess
import urllib.request
from pathlib import Path
import imageio_ffmpeg

ROOT = Path(__file__).resolve().parents[1]
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()
SELECTIONS = '''heath-slater|10|One Man Band
luke-harper|0|Swamp Gas
bo-dallas|0|Shoot for the Stars
samoa-joe|1|Destroyer
neville|0|Break Orbit
braun-strowman|1|Monster
elias|0|Drift
andrade|2|Making a Difference
matt-riddle|2|Hey Bro
keith-lee|3|Limitless
tommaso-ciampa|0|No One Will Survive
adam-cole|2|All About Tha (Boom!)
ilja-dragunov|0|Death Waltz
ric-flair|2|Ric Flair
goldberg|0|Invasion
carmella|0|Fabulous
ruby-riott|0|We Riot
sonya-deville|1|Square Up
mandy-rose|2|I've Arrived
lacey-evans|2|Like a Lady
shayna-baszler|0|Loyalty Is Everything
kairi-sane|0|The Next Voyage
dakota-kai|0|Kombat
toni-storm|2|Take Cover
zelina-vega|0|The Doll (La Muñeca)
nikki-cross|1|Glasgow Cross
dana-brooke|2|See You
peyton-royce|0|Sultry (XO)
billie-kay|2|Femme Fatale
paul-london|0|Rocker
brian-kendrick|1|Man with a Plan
jamie-noble|2|2 Z' Top
chuck-palumbo|20|You Will Remember Me
mike-knox|1|Mike Knox
kenny-dykstra|0|Kenny Dykstra
lance-cade|0|Cade & Murdoch
trevor-murdoch|0|Cade & Murdoch
rene-dupree|0|René Duprée
funaki|4|Kung Fu San
kevin-thorn|0|Mi Destrojero
stevie-richards|0|Paging Dr. Stevie
sabu|2|Huka Blues
luke-gallows|1|Omen in the Sky
karl-anderson|1|Omen in the Sky
yoshi-tatsu|4|J-Pop Drop
tyler-breeze|3|#MMMGorgeous
aiden-english|1|Bel Canto
mojo-rawley|3|Killer Instinct
hideo-itami|1|Tokiwakita
roderick-strong|2|Next Level
kyle-o-reilly|2|Undisputed
ec3|0|Top One Percent
eric-young|0|Vintage
big-cass|3|SAWFT Is a Sin
enzo-amore|2|SAWFT Is a Sin
erick-rowan|0|Erick Rowan
buddy-murphy|0|Opposite Ends of the World
cedric-alexander|1|Won't Let Go
drew-gulak|0|For the Better
santos-escobar|1|Soul March
wes-lee|0|Assemble
kristal-marshall|2|Kristal Marshall
brooke-adams|3|Don't Stop
serena-deeb|3|The Professor
sarah-logan|1|Backwoods Man
xia-li|2|Fighting Spirit
shotzi|16|I Am a Psycho
tegan-nox|4|Blue Marvel
gigi-dolin|2|Watch Me Now
cora-jade|3|Generation of Jade
katana-chance|0|Party All the Time
kayden-carter|1|Party All the Time
alba-fyre|1|Dare Devil
sylvester-lefort|0|France Rules
tonga-loa|0|G.O.D. (Firing Squad)
velveteen-dream|3|Velveteen
cain-velasquez|29|Combatiente
paul-heyman|0|Paul Heyman
vickie-guerrero|0|Excuse Me
john-laurinaitis|2|John Laurinaitis
jim-ross|16|Boomer Sooner
corey-graves|14|Dead and Gone
lilian-garcia|0|You Just Don't Know Me at All
bad-bunny|4|Chambea
mustafa-ali|17|Go Hard
liv-morgan|1|Trouble'''


def build(item):
    slug, song, label = item
    path = ROOT / 'audio' / (slug + '.mp3')
    try:
        with urllib.request.urlopen(song['url'], timeout=30) as response:
            if 'audio' not in response.headers.get('Content-Type', ''):
                raise ValueError('Not an audio response')
            raw = response.read(25_000_001)
        if len(raw) > 25_000_000:
            raise ValueError('Unexpectedly large audio response')
        result = subprocess.run([FFMPEG, '-hide_banner', '-loglevel', 'error', '-y', '-i', 'pipe:0',
            '-t', '30', '-vn', '-map_metadata', '-1', '-af',
            'loudnorm=I=-18:TP=-2:LRA=11,afade=t=in:d=0.08,afade=t=out:st=28.5:d=1.5',
            '-ar', '44100', '-ac', '2', '-codec:a', 'libmp3lame', '-b:a', '128k', str(path)],
            input=raw, capture_output=True, timeout=45,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0)
        if result.returncode:
            raise ValueError(result.stderr.decode(errors='replace')[:200])
        return slug, {'u':'audio/' + path.name, 't':label, 'source':song['source'],
                      'sourceTitle':song['title'], 'sourceArtist':song['artist'],
                      'sha256':hashlib.sha256(path.read_bytes()).hexdigest(), 'bytes':path.stat().st_size}
    except Exception as error:
        return slug, {'error':str(error)}


if __name__ == '__main__':
    data = json.loads((ROOT/'tools/direct-candidates.json').read_text(encoding='utf-8'))
    report_path = ROOT/'tools/local-music-report.json'
    report = json.loads(report_path.read_text(encoding='utf-8')) if report_path.exists() else {}
    # Amale uses a verified direct preview in themes.js.
    report.pop('amale', None)
    targets = []
    for line in SELECTIONS.splitlines():
        slug, index, label = line.split('|')
        song = data[slug][int(index)]
        old = report.get(slug, {})
        path = ROOT / old.get('u', 'missing')
        if (old.get('t') == label and old.get('sourceTitle') == song['title'] and path.is_file()
                and old.get('sha256') == hashlib.sha256(path.read_bytes()).hexdigest()):
            continue
        targets.append((slug, song, label))
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        report.update(pool.map(build, targets))
    (ROOT/'tools/local-music-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    catalog = {key:{'u':v['u'],'t':v['t']} for key,v in report.items() if 'u' in v}
    (ROOT/'themes-local.js').write_text('// Generated by tools/build-local-music.py.\nwindow.THEMES_LOCAL = '+json.dumps(catalog,ensure_ascii=False)+';\n',encoding='utf-8')
    print(f'{len(catalog)} local clips available; {len(targets)} attempted this run.')
    for key,value in report.items():
        if 'error' in value: print(key,value['error'])
