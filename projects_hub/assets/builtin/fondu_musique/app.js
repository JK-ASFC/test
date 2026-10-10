'use strict';

/* Fondu musique — two-deck player that crossfades between local tracks.
 *
 * Each deck is an <audio> element routed through its own GainNode; fades are
 * scheduled on the Web Audio clock (not JS timers) so they stay smooth even
 * when the screen is off. Tracks come from the phone's storage through the
 * Mes Projets local server (/__hub/music), or from files picked by hand.
 */

const $ = (s) => document.querySelector(s);
const STORE = 'fondu.v1';

const DEFAULT_SETTINGS = {
  fade: 6,           // seconds
  curve: 'equal',    // equal | smooth | linear
  auto: true,        // crossfade into the next track before the end
  fadePause: true,   // short fade on pause/resume
  fadeSkip: false,   // full crossfade on prev/next buttons too
  volume: 1,
};

const state = {
  queue: [],         // {id, name, folder, src, imported}
  index: -1,
  repeat: 'all',     // all | one | off
  settings: { ...DEFAULT_SETTINGS },
};

let library = [];    // tracks found on the phone
let importCounter = 0;

// ---------------------------------------------------------------- storage

function save() {
  try {
    const cur = state.queue[state.index];
    localStorage.setItem(STORE, JSON.stringify({
      queue: state.queue.filter((t) => !t.imported).map(({ id, name, folder, src }) => ({ id, name, folder, src })),
      currentId: cur && !cur.imported ? cur.id : null,
      repeat: state.repeat,
      settings: state.settings,
    }));
  } catch (_) { /* storage full or disabled */ }
}

function restore() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE) || 'null');
    if (!raw) return;
    state.queue = Array.isArray(raw.queue) ? raw.queue : [];
    state.repeat = ['all', 'one', 'off'].includes(raw.repeat) ? raw.repeat : 'all';
    state.settings = { ...DEFAULT_SETTINGS, ...(raw.settings || {}) };
    state.index = state.queue.findIndex((t) => t.id === raw.currentId);
    if (state.index < 0 && state.queue.length) state.index = 0;
  } catch (_) { /* corrupted: start fresh */ }
}

// ---------------------------------------------------------------- audio engine

let ctx = null;
let master = null;
const decks = [makeDeck('A'), makeDeck('B')];
let active = 0;        // deck currently "on air"
let fading = false;    // a crossfade is running
let fadeTimer = null;
let pauseTimer = null;
let request = 0;       // id of the latest crossfadeTo() call

function makeDeck(name) {
  const el = new Audio();
  el.preload = 'auto';
  const deck = { name, el, gain: null, track: null };
  el.addEventListener('timeupdate', () => onTimeUpdate(deck));
  el.addEventListener('ended', () => onEnded(deck));
  el.addEventListener('error', () => onError(deck));
  return deck;
}

/** Creates the AudioContext on the first user gesture (autoplay policy). */
function ensureAudio() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) {
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = state.settings.volume;
      master.connect(ctx.destination);
      decks.forEach((d, i) => {
        const src = ctx.createMediaElementSource(d.el);
        d.gain = ctx.createGain();
        d.gain.gain.value = i === active ? 1 : 0;
        src.connect(d.gain);
        d.gain.connect(master);
      });
    }
  }
  if (ctx && ctx.state === 'suspended') ctx.resume();
}

/** Fade-in shape, f(0)=0 → f(1)=1. Fade-outs use f(1-t). */
function shape(t) {
  switch (state.settings.curve) {
    case 'linear': return t;
    case 'smooth': return 0.5 - 0.5 * Math.cos(Math.PI * t);
    default: return Math.sin((t * Math.PI) / 2); // equal power: constant loudness
  }
}

function currentGain(deck) {
  return deck.gain ? deck.gain.gain.value : deck.el.volume;
}

/** Ramps a deck's volume to [to] over [dur] seconds. */
function ramp(deck, to, dur) {
  const from = currentGain(deck);
  if (deck.gain && ctx) {
    const g = deck.gain.gain;
    const now = ctx.currentTime;
    if (g.cancelAndHoldAtTime) g.cancelAndHoldAtTime(now); else g.cancelScheduledValues(now);
    if (dur <= 0 || Math.abs(to - from) < 0.001) {
      g.setValueAtTime(to, now);
      return;
    }
    const n = Math.max(16, Math.round(dur * 30));
    const curve = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const t = i / (n - 1);
      curve[i] = to >= from ? from + (to - from) * shape(t) : to + (from - to) * shape(1 - t);
    }
    try {
      // Start just after the hold point so the curve never overlaps it.
      g.setValueCurveAtTime(curve, now + 0.005, dur);
    } catch (_) {
      g.setValueAtTime(from, now);
      g.linearRampToValueAtTime(to, now + dur);
    }
    return;
  }
  // No Web Audio: step el.volume (less smooth, still works).
  const start = performance.now();
  clearInterval(deck.volTimer);
  if (dur <= 0) { deck.el.volume = to; return; }
  deck.volTimer = setInterval(() => {
    const t = Math.min(1, (performance.now() - start) / (dur * 1000));
    deck.el.volume = to >= from ? from + (to - from) * shape(t) : to + (from - to) * shape(1 - t);
    if (t >= 1) clearInterval(deck.volTimer);
  }, 40);
}

function isPlaying(deck) {
  return !!deck.track && !deck.el.paused && !deck.el.ended;
}

function stopDeck(deck) {
  deck.el.pause();
  ramp(deck, 0, 0);
}

function nextIndex() {
  const n = state.queue.length;
  if (!n) return -1;
  if (state.repeat === 'one') return state.index;
  if (state.index + 1 < n) return state.index + 1;
  return state.repeat === 'all' ? 0 : -1;
}

function prevIndex() {
  const n = state.queue.length;
  if (!n) return -1;
  if (state.index > 0) return state.index - 1;
  return state.repeat === 'all' ? n - 1 : 0;
}

/**
 * Starts queue[idx] on the free deck and crossfades into it over [dur]
 * seconds. If nothing is playing, it simply starts (with a fade-in when
 * [dur] > 0 and fade on pause/resume is enabled).
 */
async function crossfadeTo(idx, dur = state.settings.fade) {
  const track = state.queue[idx];
  if (!track) return;
  ensureAudio();
  clearTimeout(pauseTimer);

  const out = decks[active];
  const inn = decks[1 - active];

  // A crossfade was still running: drop the deck that was fading out.
  clearTimeout(fadeTimer);
  if (inn.track) stopDeck(inn);

  const req = ++request;
  fading = true;
  state.index = idx;
  inn.track = track;
  inn.el.src = track.src;
  ramp(inn, 0, 0);
  try {
    await inn.el.play();
  } catch (e) {
    if (req !== request) return; // replaced by a newer request
    fading = false;
    toast(`Lecture impossible : ${track.name}`);
    render();
    return;
  }

  if (req !== request) return;
  const outWasPlaying = isPlaying(out);
  active = 1 - active;
  if (outWasPlaying && dur > 0) {
    ramp(out, 0, dur);
    ramp(inn, 1, dur);
    fadeTimer = setTimeout(() => {
      stopDeck(out);
      fading = false;
      render();
    }, dur * 1000 + 80);
  } else {
    if (outWasPlaying) stopDeck(out);
    ramp(inn, 1, !outWasPlaying && state.settings.fadePause ? Math.min(dur, 1.5) : 0);
    fading = false;
  }
  updateMediaSession();
  save();
  render();
}

function skipDuration() {
  return state.settings.fadeSkip ? state.settings.fade : Math.min(1, state.settings.fade);
}

function onTimeUpdate(deck) {
  if (deck !== decks[active] || fading || !state.settings.auto) return;
  const d = deck.el.duration;
  if (!isFinite(d) || d <= 0 || deck.el.paused) return;
  const fade = state.settings.fade;
  if (fade <= 0 || d < fade * 2) return; // too short to overlap: 'ended' handles it
  if (d - deck.el.currentTime <= fade) {
    const n = nextIndex();
    if (n >= 0) crossfadeTo(n, fade);
  }
}

function onEnded(deck) {
  if (deck !== decks[active] || fading) return;
  const n = nextIndex();
  if (n >= 0) crossfadeTo(n, 0);
  else render();
}

function onError(deck) {
  if (!deck.track || deck !== decks[active]) return;
  toast(`Fichier illisible : ${deck.track.name}`);
}

function togglePlay() {
  ensureAudio();
  const deck = decks[active];
  if (!deck.track) {
    if (state.queue.length) crossfadeTo(Math.max(0, state.index), 0);
    else { switchTab('library'); toast('Ajoute d\'abord des musiques'); }
    return;
  }
  const soft = state.settings.fadePause ? 0.6 : 0;
  if (isPlaying(deck)) {
    // Pause: also stops a crossfade in progress.
    clearTimeout(fadeTimer);
    const other = decks[1 - active];
    if (isPlaying(other)) stopDeck(other);
    fading = false;
    ramp(deck, 0, soft);
    clearTimeout(pauseTimer);
    pauseTimer = setTimeout(() => { deck.el.pause(); render(); }, soft * 1000);
  } else {
    clearTimeout(pauseTimer);
    ramp(deck, 0, 0);
    deck.el.play().then(() => ramp(deck, 1, soft)).catch(() => toast('Lecture impossible'));
  }
  render();
}

function goNext() {
  const n = nextIndex();
  if (n >= 0) crossfadeTo(n, skipDuration());
  else toast('Fin de la file d\'attente');
}

function goPrev() {
  const deck = decks[active];
  if (deck.track && deck.el.currentTime > 4) {
    deck.el.currentTime = 0;
    return;
  }
  const p = prevIndex();
  if (p >= 0) crossfadeTo(p, skipDuration());
}

// ---------------------------------------------------------------- queue

function addToQueue(tracks, { playNow = false } = {}) {
  const list = Array.isArray(tracks) ? tracks : [tracks];
  if (!list.length) return;
  const at = playNow && state.index >= 0 ? state.index + 1 : state.queue.length;
  state.queue.splice(at, 0, ...list.map((t) => ({ ...t })));
  if (state.index < 0) state.index = 0;
  save();
  render();
  if (playNow) crossfadeTo(at);
  else toast(list.length === 1 ? `Ajouté : ${list[0].name}` : `${list.length} morceaux ajoutés`);
}

function removeAt(i) {
  const wasCurrent = i === state.index;
  state.queue.splice(i, 1);
  if (i < state.index) state.index--;
  if (wasCurrent) {
    // Keep the current song playing; it is just no longer queued.
    state.index = Math.min(state.index, state.queue.length - 1);
  }
  save();
  render();
}

function move(i, delta) {
  const j = i + delta;
  if (j < 0 || j >= state.queue.length) return;
  const [t] = state.queue.splice(i, 1);
  state.queue.splice(j, 0, t);
  if (state.index === i) state.index = j;
  else if (state.index === j) state.index = i;
  save();
  render();
}

function shuffle() {
  if (state.queue.length < 2) return;
  const cur = state.queue[state.index];
  const rest = state.queue.filter((_, i) => i !== state.index);
  for (let i = rest.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [rest[i], rest[j]] = [rest[j], rest[i]];
  }
  state.queue = cur ? [cur, ...rest] : rest;
  state.index = 0;
  save();
  render();
  toast('File mélangée');
}

// ---------------------------------------------------------------- library

const hasHub = () => location.protocol.startsWith('http');
let libLoading = false;
let needPermission = false;

async function loadLibrary(refresh = false) {
  if (!hasHub() || libLoading) return;
  libLoading = true;
  $('#libInfo').textContent = 'Recherche des musiques…';
  try {
    const res = await fetch(`/__hub/music${refresh ? '?refresh=1' : ''}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(String(res.status));
    const data = await res.json();
    needPermission = !!data.needPermission;
    library = (data.tracks || []).map((t) => ({
      id: t.path,
      name: prettify(t.name),
      folder: t.folder,
      src: `/__hub/music/file?p=${encodeURIComponent(t.path)}`,
    }));
    $('#perm').classList.toggle('hidden', !needPermission);
    $('#libInfo').textContent = needPermission ? '' : `${library.length} morceau${library.length > 1 ? 'x' : ''}`;
  } catch (_) {
    library = [];
    $('#libInfo').textContent = 'Bibliothèque indisponible ici : importe tes fichiers.';
  } finally {
    libLoading = false;
    renderLibrary();
  }
}

function prettify(name) {
  return name.replace(/[_]+/g, ' ').replace(/\s+/g, ' ').trim();
}

function importFiles(files) {
  const tracks = [...files]
    .filter((f) => f.type.startsWith('audio/') || /\.(mp3|m4a|aac|ogg|oga|opus|wav|flac|webm)$/i.test(f.name))
    .map((f) => ({
      id: `import:${++importCounter}:${f.name}`,
      name: prettify(f.name.replace(/\.[^.]+$/, '')),
      folder: 'Importé (cette session)',
      src: URL.createObjectURL(f),
      imported: true,
    }));
  if (!tracks.length) return toast('Aucun fichier audio');
  addToQueue(tracks);
  switchTab('queue');
}

// ---------------------------------------------------------------- UI

const ICON_PLAY = '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>';
const ICON_PAUSE = '<svg viewBox="0 0 24 24"><path d="M6 5h4v14H6zm8 0h4v14h-4z"/></svg>';

function fmt(s) {
  if (!isFinite(s) || s < 0) return '0:00';
  const m = Math.floor(s / 60);
  const r = Math.floor(s % 60);
  return `${m}:${String(r).padStart(2, '0')}`;
}

function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

let seeking = false;
let toastTimer = null;

function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 2200);
}

function switchTab(name) {
  document.querySelectorAll('.tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === name));
  document.querySelectorAll('.tab').forEach((s) => s.classList.toggle('hidden', s.id !== `tab-${name}`));
  if (name === 'library' && !library.length && !libLoading) loadLibrary();
}

function render() {
  const deck = decks[active];
  const cur = deck.track || state.queue[state.index];
  const playing = isPlaying(deck);
  $('#title').textContent = cur ? cur.name : 'Aucun morceau';
  $('#sub').textContent = cur ? cur.folder || '' : 'Ajoute des musiques depuis la bibliothèque';
  $('#play').innerHTML = playing ? ICON_PAUSE : ICON_PLAY;
  $('#play').setAttribute('aria-label', playing ? 'Pause' : 'Lecture');
  $('#art').classList.toggle('playing', playing);
  const n = nextIndex();
  $('#upNext').textContent = `Ensuite : ${n >= 0 && state.queue[n] ? state.queue[n].name : '—'}`;
  $('#fadeLabel').textContent = `${state.settings.fade} s`;
  $('#qCount').textContent = state.queue.length;
  renderQueue(playing);
}

function renderQueue(playing) {
  const ol = $('#queue');
  $('#queueEmpty').classList.toggle('hidden', state.queue.length > 0);
  ol.innerHTML = state.queue.map((t, i) => `
    <li class="row${i === state.index ? ' current' : ''}" data-i="${i}">
      ${i === state.index
        ? `<span class="eq${playing ? '' : ' paused'}"><i></i><i></i><i></i></span>`
        : `<span class="num">${i + 1}</span>`}
      <div class="txt" data-act="play"><div class="name">${esc(t.name)}</div><div class="folder">${esc(t.folder || '')}</div></div>
      <button class="btn" data-act="up" aria-label="Monter">↑</button>
      <button class="btn" data-act="down" aria-label="Descendre">↓</button>
      <button class="btn" data-act="remove" aria-label="Retirer">✕</button>
    </li>`).join('');
}

function renderLibrary() {
  const box = $('#library');
  const q = $('#search').value.trim().toLowerCase();
  const tracks = q
    ? library.filter((t) => t.name.toLowerCase().includes(q) || (t.folder || '').toLowerCase().includes(q))
    : library;
  if (!tracks.length) {
    box.innerHTML = needPermission ? '' : `<div class="empty">${library.length ? 'Aucun résultat.' : (hasHub() ? 'Aucune musique trouvée sur le téléphone.' : '')}</div>`;
    return;
  }
  const groups = new Map();
  for (const t of tracks) {
    if (!groups.has(t.folder)) groups.set(t.folder, []);
    groups.get(t.folder).push(t);
  }
  const openAll = groups.size === 1 || !!q;
  box.innerHTML = [...groups.entries()].map(([folder, list], gi) => `
    <details class="folder" data-g="${gi}" ${openAll ? 'open' : ''}>
      <summary>
        <span class="fname">📁 ${esc(folder)}</span>
        <span class="fcount">${list.length}</span>
        <button class="chip" data-act="addAll">+ Tout</button>
      </summary>
      <div class="tracks">${openAll ? rowsFor(list) : ''}</div>
    </details>`).join('');
  box._groups = [...groups.values()];
}

function rowsFor(list) {
  return list.map((t, i) => `
    <div class="row" data-t="${i}">
      <div class="txt" data-act="playNow"><div class="name">${esc(t.name)}</div></div>
      <button class="btn add" data-act="add" aria-label="Ajouter à la file">+</button>
    </div>`).join('');
}

function renderSettings() {
  const s = state.settings;
  $('#fade').value = s.fade;
  $('#fadeVal').textContent = `${s.fade} s`;
  $('#auto').checked = s.auto;
  $('#fadePause').checked = s.fadePause;
  $('#fadeSkip').checked = s.fadeSkip;
  $('#volume').value = s.volume;
  $('#volVal').textContent = `${Math.round(s.volume * 100)} %`;
  document.querySelectorAll('#curve button').forEach((b) => b.classList.toggle('active', b.dataset.v === s.curve));
  const pts = (fn) => Array.from({ length: 41 }, (_, i) => {
    const t = i / 40;
    return `${(t * 100).toFixed(1)},${(38 - fn(t) * 36).toFixed(1)}`;
  }).join(' ');
  $('#curvePreview').innerHTML =
    `<path d="M${pts((t) => shape(1 - t))}" stroke="#ff5ca8"/><path d="M${pts(shape)}" stroke="#b45cff"/>`;
  document.querySelectorAll('input[type=range]').forEach(paintRange);
  render();
}

function paintRange(r) {
  const min = +r.min || 0;
  const max = +r.max || 1;
  r.style.setProperty('--p', `${((r.value - min) / (max - min)) * 100}%`);
}

/** Progress bar and A/B meters, refreshed continuously. */
function tick() {
  const deck = decks[active];
  const d = deck.el.duration;
  if (!seeking) {
    const seek = $('#seek');
    seek.value = isFinite(d) && d > 0 ? Math.round((deck.el.currentTime / d) * 1000) : 0;
    paintRange(seek);
  }
  $('#cur').textContent = fmt(deck.el.currentTime);
  $('#dur').textContent = fmt(d);
  const level = (k) => (decks[k].track && !decks[k].el.paused ? currentGain(decks[k]) : 0);
  $('#mixA').style.width = `${Math.round(level(0) * 100)}%`;
  $('#mixB').style.width = `${Math.round(level(1) * 100)}%`;
  requestAnimationFrame(tick);
}

function updateMediaSession() {
  if (!('mediaSession' in navigator)) return;
  const t = decks[active].track;
  try {
    navigator.mediaSession.metadata = t ? new MediaMetadata({ title: t.name, artist: t.folder || '', album: 'Fondu musique' }) : null;
  } catch (_) { /* MediaMetadata unsupported */ }
}

function bind() {
  $('#play').addEventListener('click', togglePlay);
  $('#next').addEventListener('click', goNext);
  $('#prev').addEventListener('click', goPrev);
  $('#fadeNow').addEventListener('click', () => {
    const n = nextIndex();
    if (n < 0) return toast('Rien à enchaîner');
    crossfadeTo(n, state.settings.fade);
  });

  const seek = $('#seek');
  seek.addEventListener('input', () => { seeking = true; paintRange(seek); });
  seek.addEventListener('change', () => {
    const el = decks[active].el;
    if (isFinite(el.duration)) el.currentTime = (seek.value / 1000) * el.duration;
    seeking = false;
  });

  document.querySelectorAll('.tabs button').forEach((b) => b.addEventListener('click', () => switchTab(b.dataset.tab)));
  document.querySelectorAll('[data-goto]').forEach((b) => b.addEventListener('click', () => switchTab(b.dataset.goto)));

  $('#queue').addEventListener('click', (e) => {
    const act = e.target.closest('[data-act]');
    const li = e.target.closest('li[data-i]');
    if (!act || !li) return;
    const i = +li.dataset.i;
    switch (act.dataset.act) {
      case 'play': crossfadeTo(i); break;
      case 'up': move(i, -1); break;
      case 'down': move(i, 1); break;
      case 'remove': removeAt(i); break;
    }
  });

  $('#shuffle').addEventListener('click', shuffle);
  $('#repeat').addEventListener('click', () => {
    state.repeat = { all: 'one', one: 'off', off: 'all' }[state.repeat];
    renderRepeat();
    save();
    render();
  });
  $('#clear').addEventListener('click', () => {
    if (!state.queue.length || !confirm('Vider la file d\'attente ?')) return;
    state.queue = [];
    state.index = -1;
    save();
    render();
  });

  const lib = $('#library');
  lib.addEventListener('toggle', (e) => {
    const det = e.target;
    if (det.tagName !== 'DETAILS' || !det.open) return;
    const tracks = det.querySelector('.tracks');
    if (!tracks.innerHTML.trim()) tracks.innerHTML = rowsFor(lib._groups[+det.dataset.g]);
  }, true);
  lib.addEventListener('click', (e) => {
    const act = e.target.closest('[data-act]');
    const det = e.target.closest('details[data-g]');
    if (!act || !det) return;
    const group = lib._groups[+det.dataset.g];
    if (act.dataset.act === 'addAll') {
      e.preventDefault();
      addToQueue(group);
      return;
    }
    const row = e.target.closest('[data-t]');
    if (!row) return;
    const t = group[+row.dataset.t];
    if (act.dataset.act === 'add') addToQueue(t);
    if (act.dataset.act === 'playNow') addToQueue(t, { playNow: true });
  });

  let searchTimer = null;
  $('#search').addEventListener('input', () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(renderLibrary, 150);
  });
  $('#refresh').addEventListener('click', () => loadLibrary(true));
  $('#import').addEventListener('change', (e) => { importFiles(e.target.files); e.target.value = ''; });
  $('#grant').addEventListener('click', () => {
    if (window.HubBridge) window.HubBridge.postMessage('requestMusicPermission');
    else toast('Ouvre Fondu musique depuis Mes Projets');
  });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && needPermission) loadLibrary(true);
  });

  // Settings
  const s = state.settings;
  $('#fade').addEventListener('input', (e) => { s.fade = +e.target.value; renderSettings(); save(); });
  $('#auto').addEventListener('change', (e) => { s.auto = e.target.checked; save(); });
  $('#fadePause').addEventListener('change', (e) => { s.fadePause = e.target.checked; save(); });
  $('#fadeSkip').addEventListener('change', (e) => { s.fadeSkip = e.target.checked; save(); });
  $('#volume').addEventListener('input', (e) => {
    s.volume = +e.target.value;
    if (master) master.gain.setTargetAtTime(s.volume, ctx.currentTime, 0.02);
    else decks.forEach((d) => { d.el.volume = Math.min(1, s.volume); });
    renderSettings();
    save();
  });
  $('#curve').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-v]');
    if (!b) return;
    s.curve = b.dataset.v;
    renderSettings();
    save();
  });

  if ('mediaSession' in navigator) {
    const ms = navigator.mediaSession;
    const set = (a, fn) => { try { ms.setActionHandler(a, fn); } catch (_) { /* unsupported */ } };
    set('play', () => { if (!isPlaying(decks[active])) togglePlay(); });
    set('pause', () => { if (isPlaying(decks[active])) togglePlay(); });
    set('nexttrack', goNext);
    set('previoustrack', goPrev);
  }
}

function renderRepeat() {
  const b = $('#repeat');
  b.textContent = { all: '🔁 Tout répéter', one: '🔂 Répéter 1', off: '➡️ Sans répétition' }[state.repeat];
  b.classList.toggle('on', state.repeat !== 'off');
}

restore();
bind();
renderRepeat();
renderSettings();
requestAnimationFrame(tick);
if (!state.queue.length) switchTab('library');

// Handy for debugging from the WebView inspector.
window.__fondu = { state, decks, get active() { return active; }, crossfadeTo, currentGain };
