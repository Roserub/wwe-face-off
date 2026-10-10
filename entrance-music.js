/* Native audio only. Local entrance clips take priority over remote previews. */
let themeAudio = null, themeRamp = null, themeCands = [], themeIdx = 0, duelToken = 0;
let audioTok = 0, musicTimeout = null, musicEnd = null;
const audioCache = new Map(), badThemes = new Set();

function themeSources(w){
  if (!w) return [];
  return [window.THEMES_LOCAL?.[w.slug], window.THEMES?.[w.slug]].filter(s => s?.u);
}
function themeOf(w){ return themeSources(w)[0] || null; }
function clearThemeTags(){ document.querySelectorAll('.theme').forEach(t => t.textContent = ''); }
function cacheAudio(source){
  if (audioCache.has(source.u)) return audioCache.get(source.u);
  const audio = new Audio(source.u);
  audio.preload = 'auto';
  audioCache.set(source.u, audio);
  if (audioCache.size > 24){
    for (const [key, old] of audioCache){
      if (old !== themeAudio && old !== audio){ old.pause(); old.removeAttribute('src'); audioCache.delete(key); break; }
    }
  }
  return audio;
}
function preloadTheme(w){ const source = themeOf(w); if (source) cacheAudio(source); }
function stopTheme(){
  ++audioTok;
  clearTimeout(musicTimeout); clearTimeout(musicEnd); clearInterval(themeRamp);
  musicTimeout = musicEnd = themeRamp = null;
  if (themeAudio){
    themeAudio.onended = themeAudio.onerror = themeAudio.onplaying = null;
    themeAudio.pause(); themeAudio = null;
  }
}
function startThemeAt(index, tried = 0, sourceIndex = 0){
  if (!S?.music || AUTOTEST || AUTOSHOT || !themeCands.length) return;
  stopTheme(); clearThemeTags();
  if (tried >= themeCands.length) return;
  themeIdx = ((index % themeCands.length) + themeCands.length) % themeCands.length;
  const pick = themeCands[themeIdx], sources = themeSources(pick[0]);
  while (sourceIndex < sources.length && badThemes.has(sources[sourceIndex].u)) sourceIndex++;
  if (sourceIndex >= sources.length){ startThemeAt(themeIdx + 1, tried + 1); return; }
  const source = sources[sourceIndex], token = audioTok;
  const active = () => token === audioTok && S?.music;
  const next = () => {
    if (!active()) return;
    if (!locked && themeCands.length > 1) startThemeAt(themeIdx + 1);
    else { stopTheme(); clearThemeTags(); }
  };
  let started = false;
  const playing = () => {
    if (!active() || started) return;
    started = true;
    clearTimeout(musicTimeout);
    const tag = pick[1]?.querySelector('.theme');
    if (tag) tag.textContent = '♪ ' + source.t;
    musicEnd = setTimeout(next, 30000);
    themeRamp = setInterval(() => {
      if (!active()){ clearInterval(themeRamp); return; }
      audio.volume = Math.min(.45, audio.volume + .045);
      if (audio.volume >= .45) clearInterval(themeRamp);
    }, 70);
  };
  const fail = error => {
    if (!active()) return;
    if (error?.name === 'NotAllowedError' || error?.name === 'AbortError'){
      stopTheme(); clearThemeTags(); return;
    }
    badThemes.add(source.u);
    startThemeAt(themeIdx, tried, sourceIndex + 1);
  };
  const audio = cacheAudio(source);
  themeAudio = audio;
  audio.volume = 0;
  try { audio.currentTime = 0; } catch (_) {}
  audio.onplaying = playing;
  audio.onended = next;
  audio.onerror = fail;
  musicTimeout = setTimeout(fail, source.u.startsWith('audio/') ? 3000 : 8000);
  audio.play().then(() => { if (active()) playing(); }).catch(fail);
}
function playTheme(){
  stopTheme(); clearThemeTags();
  themeCands = [[cur.L, els.fL], [cur.R, els.fR]].filter(c => themeOf(c[0]));
  if (themeCands.length) startThemeAt(Math.floor(Math.random() * themeCands.length));
}
