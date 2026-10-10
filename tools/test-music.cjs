// Run with Node. Exercises source priority and asynchronous playback failures.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const audio = [], timers = new Map();
let timerId = 0;
class AudioStub {
  constructor(src){ this.src=src; this.paused=true; this.volume=0; this.currentTime=0; audio.push(this); }
  play(){ this.paused=false; return this.denied ? Promise.reject(Object.assign(new Error(),{name:'NotAllowedError'})) : Promise.resolve(); }
  pause(){ this.paused=true; }
  removeAttribute(){ this.src=''; }
}
const tags = [{textContent:''}];
const context = vm.createContext({window:{}, S:{music:true}, locked:false, AUTOTEST:false, AUTOSHOT:false,
  Audio:AudioStub, document:{querySelectorAll:()=>tags},
  setTimeout:(fn,ms)=>{timers.set(++timerId,{fn,ms});return timerId},clearTimeout:id=>timers.delete(id),
  setInterval:()=>++timerId,clearInterval:()=>{}, console });
for(const file of ['themes.js','themes-local.js','entrance-music.js']) vm.runInContext(fs.readFileSync(path.join(root,file),'utf8'),context);
const run = code => vm.runInContext(code, context);
const flush = () => new Promise(resolve => setImmediate(resolve));
(async()=>{
  assert.equal(run("themeOf({slug:'liv-morgan'}).t"),'Trouble');
  assert.equal(run("themeOf({slug:'liv-morgan'}).u"),'audio/liv-morgan.mp3');
  assert.equal(run("themeOf({slug:'unknown'})"),null);
  run("themeCands=[[{slug:'liv-morgan'},null]];startThemeAt(0)");await flush();
  assert.equal(run('themeAudio.src'),'audio/liv-morgan.mp3');
  const prior=audio.at(-1); run('stopTheme();S.music=false;startThemeAt(0)');
  assert(prior.paused);assert.equal(run('themeAudio'),null);
  // A local error falls back to the same character's remote source.
  run("S.music=true;window.THEMES_LOCAL.test={u:'audio/missing.mp3',t:'Local'};window.THEMES.test={u:'https://example.org/preview.mp3',t:'Remote'};themeCands=[[{slug:'test'},null]];startThemeAt(0)");
  const failed=audio.at(-1); failed.onerror();await flush();
  assert(failed.paused);assert.equal(run('themeAudio.src'),'https://example.org/preview.mp3');
  // Late callbacks from the previous selection cannot skip the new selection.
  const oldEnd=run('themeAudio.onended');run("themeCands=[[{slug:'liv-morgan'},null]];startThemeAt(0)");oldEnd();await flush();
  assert.equal(run('themeAudio.src'),'audio/liv-morgan.mp3');
  // A load timeout advances to another known theme; it never creates a fake theme.
  run("window.THEMES.hang={u:'https://example.org/hang.mp3',t:'Hang'};themeCands=[[{slug:'hang'},null],[{slug:'liv-morgan'},null]];startThemeAt(0)");
  [...timers.values()].find(t=>t.ms===8000).fn();await flush();
  assert.equal(run('themeAudio.src'),'audio/liv-morgan.mp3');
  // Autoplay refusal is recoverable with the existing controls.
  run("stopTheme();const denied=cacheAudio({u:'audio/denied.mp3'});denied.denied=true;window.THEMES_LOCAL.denied={u:'audio/denied.mp3',t:'Denied'};themeCands=[[{slug:'denied'},null]];startThemeAt(0)");await flush();
  assert.equal(run("badThemes.has('audio/denied.mp3')"),false);
  assert.equal(run('themeAudio'),null);
  run('stopTheme()');assert.equal(timers.size,0);
  const html=fs.readFileSync(path.join(root,'index.html'),'utf8');
  assert(!/musicDock|ytHost|themes-yt\.js|arena-original/.test(html));
  console.log('PASS: Trouble selection, local priority, stop/mute, source recovery, stale callbacks, timeout, autoplay retry, no added player UI.');
})().catch(error=>{console.error(error);process.exitCode=1});
