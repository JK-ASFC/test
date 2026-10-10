'use strict';

/* Boom Player — version téléphone (Fondu musique dans Mes Projets).
 *
 * Port mobile du Boom Player PC : playlists, repères de couleur entre les
 * chansons, balises, file d'attente modifiable, fondu enchaîné (aussi au
 * skip), doublons, renommage par appui long, import/export .json compatible
 * avec la version PC (les morceaux se retrouvent par nom de fichier).
 *
 * Les musiques viennent du stockage du téléphone via le serveur local de Mes
 * Projets (/__hub/music). Deux platines <audio> A/B passent chacune par un
 * GainNode ; les fondus sont planifiés sur l'horloge Web Audio, donc restent
 * fluides écran éteint.
 */

const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const STORE = 'boomPhone.v1';
const MARKER_COLORS = ['#ff4d6d', '#ff922b', '#fcc419', '#51cf66', '#339af0', '#b45cff'];

const DEFAULT_SETTINGS = {
  fade: 6,
  curve: 'equal',     // equal | smooth | linear
  auto: true,         // fondu automatique avant la fin
  fadeSkip: true,     // fondu aussi sur ⏮ / ⏭ / choix d'un morceau
  fadePause: true,
  ambient: true,
  volume: 1,
  shuffle: false,
  loop: 'all',        // all | one | off
  hideDupes: false,
};

/** Persisted state. Tracks are referenced by key = file name (like Boom Player PC). */
let S = {
  meta: {},           // key -> { customTitle, customArtist, tags[], duration, name, artist }
  playlists: [],      // { id, name, keys[], markers[{ id, after: key|null, label, color }] }
  queue: { keys: [], pos: -1, source: null, original: null },
  settings: { ...DEFAULT_SETTINGS },
};

let library = [];          // tracks on this phone (+ imported this session)
const byKey = new Map();   // key -> track
let view = 'now';
let openPl = null;         // playlist id shown in detail
let libTag = null;
let plTag = null;
let selecting = false;
let selTarget = null;      // playlist id when adding tracks to it
const selected = new Set();
let needPermission = false;
let libLoaded = false;
let libLoading = false;

// ============================================================ helpers

const uid = () => (crypto.randomUUID ? crypto.randomUUID() : `${Date.now().toString(36)}${Math.random().toString(36).slice(2)}`);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const mins = (s) => `${Math.max(1, Math.round(s / 60))} min`;
const fmt = (s) => (!isFinite(s) || s < 0 ? '0:00' : `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`);
const norm = (s) => String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, ' ').trim();

function hash(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) { h ^= s.charCodeAt(i); h = Math.imul(h, 16777619); }
  return h >>> 0;
}

let saveTimer = null;
function save() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    try { localStorage.setItem(STORE, JSON.stringify(S)); } catch (_) { toast('Stockage plein : réglages non enregistrés'); }
  }, 150);
}

function restore() {
  try {
    const raw = JSON.parse(localStorage.getItem(STORE) || 'null');
    if (!raw) return;
    S = {
      meta: raw.meta || {},
      playlists: Array.isArray(raw.playlists) ? raw.playlists : [],
      queue: { keys: [], pos: -1, source: null, original: null, ...(raw.queue || {}) },
      settings: { ...DEFAULT_SETTINGS, ...(raw.settings || {}) },
    };
    S.playlists.forEach((p) => { p.keys = p.keys || []; p.markers = p.markers || []; });
  } catch (_) { /* état corrompu : on repart de zéro */ }
}

let toastTimer = null;
function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => t.classList.remove('show'), 2600);
}

/** Messages to Mes Projets (Android). */
function bridge(msg) {
  if (window.HubBridge) { window.HubBridge.postMessage(JSON.stringify(msg)); return true; }
  return false;
}
window.__hubReply = (msg) => { if (msg && msg.text) toast(msg.text); };

// ============================================================ tracks

/** "01 - Artiste - Titre_feat.mp3" -> { title, artist } */
function parseName(rawFilename) {
  let base = rawFilename.replace(/\.[^.]+$/, '').replace(/_/g, ' ').replace(/\s+/g, ' ').trim();
  base = base.replace(/^\d{1,3}\s*[-.)]\s*/, '');
  const i = base.indexOf(' - ');
  if (i > 0) return { artist: base.slice(0, i).trim(), title: base.slice(i + 3).trim() };
  return { artist: '', title: base };
}

function makeTrack({ rawFilename, folder, src, path, imported }) {
  const p = parseName(rawFilename);
  return { key: rawFilename, rawFilename, folder, src, path, imported: !!imported, pTitle: p.title, pArtist: p.artist };
}

function indexLibrary() {
  byKey.clear();
  for (const t of library) {
    // Même nom de fichier dans deux dossiers : le premier garde la clé "nom".
    let key = t.rawFilename;
    if (byKey.has(key)) key = `${t.rawFilename}|${t.folder}`;
    t.key = key;
    byKey.set(key, t);
  }
}

const meta = (key) => S.meta[key] || {};
function setMeta(key, patch) {
  S.meta[key] = { ...meta(key), ...patch };
  save();
}
const titleOf = (key) => meta(key).customTitle || byKey.get(key)?.pTitle || meta(key).name || key;
const artistOf = (key) => meta(key).customArtist || byKey.get(key)?.pArtist || meta(key).artist || byKey.get(key)?.folder || '';
const tagsOf = (key) => meta(key).tags || [];
const has = (key) => byKey.has(key);

function allTags(keys) {
  const set = new Set();
  (keys || Object.keys(S.meta)).forEach((k) => tagsOf(k).forEach((t) => set.add(t)));
  return [...set].sort((a, b) => a.localeCompare(b, 'fr'));
}

/** Same song = same title and artist, ignoring "(1)", "- copie"… added by downloads. */
function dupKey(key) {
  const title = titleOf(key).replace(/\s*[-(]\s*(\d{1,2}|copy|copie)\s*\)?\s*$/i, '');
  return `${norm(title)}::${norm(artistOf(key))}`;
}

function visibleLibrary() {
  if (!S.settings.hideDupes) return library;
  const seen = new Set();
  return library.filter((t) => {
    const d = dupKey(t.key);
    if (seen.has(d)) return false;
    seen.add(d);
    return true;
  });
}

// ============================================================ audio engine

let ctx = null;
let master = null;
const decks = [makeDeck('A'), makeDeck('B')];
let active = 0;
let fading = false;
let fadeTimer = null;
let pauseTimer = null;
let request = 0;

function makeDeck(name) {
  const el = new Audio();
  el.preload = 'auto';
  const deck = { name, el, gain: null, key: null };
  el.addEventListener('timeupdate', () => onTimeUpdate(deck));
  el.addEventListener('ended', () => onEnded(deck));
  el.addEventListener('loadedmetadata', () => {
    if (deck.key && isFinite(el.duration) && Math.round(meta(deck.key).duration || 0) !== Math.round(el.duration)) {
      setMeta(deck.key, { duration: el.duration });
    }
  });
  el.addEventListener('play', renderPlayState);
  el.addEventListener('pause', renderPlayState);
  return deck;
}

function ensureAudio() {
  if (!ctx) {
    const AC = window.AudioContext || window.webkitAudioContext;
    if (AC) {
      ctx = new AC();
      master = ctx.createGain();
      master.gain.value = S.settings.volume;
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

function shape(t) {
  switch (S.settings.curve) {
    case 'linear': return t;
    case 'smooth': return 0.5 - 0.5 * Math.cos(Math.PI * t);
    default: return Math.sin((t * Math.PI) / 2);
  }
}

const gainOf = (d) => (d.gain ? d.gain.gain.value : d.el.volume);

function ramp(deck, to, dur) {
  const from = gainOf(deck);
  if (deck.gain && ctx) {
    const g = deck.gain.gain;
    const now = ctx.currentTime;
    if (g.cancelAndHoldAtTime) g.cancelAndHoldAtTime(now); else g.cancelScheduledValues(now);
    if (dur <= 0 || Math.abs(to - from) < 0.001) { g.setValueAtTime(to, now); return; }
    const n = Math.max(16, Math.round(dur * 30));
    const curve = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const t = i / (n - 1);
      curve[i] = to >= from ? from + (to - from) * shape(t) : to + (from - to) * shape(1 - t);
    }
    try { g.setValueCurveAtTime(curve, now + 0.005, dur); } catch (_) { g.setValueAtTime(from, now); g.linearRampToValueAtTime(to, now + dur); }
    return;
  }
  clearInterval(deck.volTimer);
  if (dur <= 0) { deck.el.volume = to; return; }
  const start = performance.now();
  deck.volTimer = setInterval(() => {
    const t = Math.min(1, (performance.now() - start) / (dur * 1000));
    deck.el.volume = to >= from ? from + (to - from) * shape(t) : to + (from - to) * shape(1 - t);
    if (t >= 1) clearInterval(deck.volTimer);
  }, 40);
}

const isPlaying = (d) => !!d.key && !d.el.paused && !d.el.ended;
function stopDeck(d) { d.el.pause(); ramp(d, 0, 0); }
const skipDur = () => (S.settings.fadeSkip ? S.settings.fade : Math.min(0.8, S.settings.fade));

/** Next playable position (skips tracks missing on this phone). */
function nextPos(from = S.queue.pos) {
  const q = S.queue.keys;
  if (!q.length) return -1;
  if (S.settings.loop === 'one' && has(q[from])) return from;
  for (let step = 1; step <= q.length; step++) {
    let i = from + step;
    if (i >= q.length) {
      if (S.settings.loop !== 'all') return -1;
      i %= q.length;
    }
    if (has(q[i])) return i;
  }
  return -1;
}

function prevPos() {
  const q = S.queue.keys;
  for (let step = 1; step <= q.length; step++) {
    let i = S.queue.pos - step;
    if (i < 0) {
      if (S.settings.loop !== 'all') return -1;
      i += q.length;
    }
    if (has(q[i])) return i;
  }
  return -1;
}

async function crossfadeTo(pos, dur = S.settings.fade) {
  const key = S.queue.keys[pos];
  const track = byKey.get(key);
  if (!track) { toast('Fichier absent de ce téléphone'); return; }
  ensureAudio();
  clearTimeout(pauseTimer);
  const out = decks[active];
  const inn = decks[1 - active];
  clearTimeout(fadeTimer);
  if (inn.key) stopDeck(inn);

  const req = ++request;
  fading = true;
  S.queue.pos = pos;
  inn.key = key;
  inn.el.src = track.src;
  ramp(inn, 0, 0);
  try {
    await inn.el.play();
  } catch (_) {
    if (req !== request) return;
    fading = false;
    toast(`Lecture impossible : ${titleOf(key)}`);
    renderAll();
    return;
  }
  if (req !== request) return;
  const outWasPlaying = isPlaying(out);
  active = 1 - active;
  if (outWasPlaying && dur > 0) {
    ramp(out, 0, dur);
    ramp(inn, 1, dur);
    fadeTimer = setTimeout(() => { stopDeck(out); fading = false; renderNow(); }, dur * 1000 + 80);
  } else {
    if (outWasPlaying) stopDeck(out);
    ramp(inn, 1, !outWasPlaying && S.settings.fadePause ? Math.min(dur || 0.8, 1.2) : 0);
    fading = false;
  }
  applyAmbient(key);
  updateMediaSession();
  save();
  renderAll();
}

function onTimeUpdate(deck) {
  if (deck !== decks[active] || fading || !S.settings.auto) return;
  const d = deck.el.duration;
  const f = S.settings.fade;
  if (!isFinite(d) || d <= 0 || deck.el.paused || f <= 0 || d < f * 2) return;
  if (d - deck.el.currentTime <= f) {
    const n = nextPos();
    if (n >= 0) crossfadeTo(n, f);
  }
}

function onEnded(deck) {
  if (deck !== decks[active] || fading) return;
  const n = nextPos();
  if (n >= 0) crossfadeTo(n, 0);
  else renderAll();
}

function togglePlay() {
  ensureAudio();
  const d = decks[active];
  if (!d.key) {
    if (S.queue.keys.length) {
      const start = has(S.queue.keys[S.queue.pos]) ? Math.max(0, S.queue.pos) : nextPos(-1);
      if (start >= 0) crossfadeTo(start, 0);
    } else {
      switchView('library');
      toast('Choisis des musiques');
    }
    return;
  }
  const soft = S.settings.fadePause ? 0.6 : 0;
  if (isPlaying(d)) {
    clearTimeout(fadeTimer);
    const other = decks[1 - active];
    if (isPlaying(other)) stopDeck(other);
    fading = false;
    ramp(d, 0, soft);
    clearTimeout(pauseTimer);
    pauseTimer = setTimeout(() => d.el.pause(), soft * 1000);
  } else {
    clearTimeout(pauseTimer);
    ramp(d, 0, 0);
    d.el.play().then(() => ramp(d, 1, soft)).catch(() => toast('Lecture impossible'));
  }
}

function goNext() {
  const n = nextPos();
  if (n >= 0) crossfadeTo(n, skipDur()); else toast('Fin de la file d\'attente');
}

function goPrev() {
  const d = decks[active];
  if (d.key && d.el.currentTime > 4) { d.el.currentTime = 0; return; }
  const p = prevPos();
  if (p >= 0) crossfadeTo(p, skipDur());
}

// ============================================================ queue

function shuffled(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/** Replaces the queue with [keys] and plays keys[start]. */
function playQueue(keys, start = 0, source = null, forceShuffle = false) {
  const playable = keys.filter(has);
  if (!playable.length) { toast('Aucun morceau disponible sur ce téléphone'); return; }
  let first = keys[start] && has(keys[start]) ? keys[start] : playable[0];
  let list = [...keys];
  if (forceShuffle || S.settings.shuffle) {
    if (forceShuffle && !S.settings.shuffle) { S.settings.shuffle = true; renderSettings(); }
    if (forceShuffle) first = playable[Math.floor(Math.random() * playable.length)];
    const rest = list.filter((k, i) => !(k === first && i === list.indexOf(first)));
    list = [first, ...shuffled(rest)];
  }
  S.queue = { keys: list, pos: list.indexOf(first), source, original: [...keys] };
  const playing = isPlaying(decks[active]);
  crossfadeTo(S.queue.pos, playing ? skipDur() : 0);
}

function enqueue(keys, next = false) {
  if (!keys.length) return;
  const q = S.queue;
  const at = next && q.pos >= 0 ? q.pos + 1 : q.keys.length;
  q.keys.splice(at, 0, ...keys);
  if (q.original) q.original.splice(Math.min(at, q.original.length), 0, ...keys);
  if (q.pos < 0) q.pos = 0;
  save();
  renderAll();
  toast(keys.length === 1 ? `${next ? 'Lu ensuite' : 'Ajouté à la file'} : ${titleOf(keys[0])}` : `${keys.length} morceaux ajoutés à la file`);
}

function setShuffle(on) {
  S.settings.shuffle = on;
  const q = S.queue;
  const cur = q.keys[q.pos];
  if (on) {
    const rest = q.keys.filter((_, i) => i !== q.pos);
    q.keys = cur !== undefined ? [cur, ...shuffled(rest)] : shuffled(rest);
    q.pos = cur !== undefined ? 0 : -1;
  } else if (q.original) {
    q.keys = [...q.original];
    q.pos = cur !== undefined ? Math.max(0, q.keys.indexOf(cur)) : -1;
  }
  save();
  renderAll();
  toast(on ? 'Aléatoire activé' : 'Ordre normal');
}

function moveInQueue(i, dir) {
  const q = S.queue;
  const j = i + dir;
  if (j < 0 || j >= q.keys.length) return;
  [q.keys[i], q.keys[j]] = [q.keys[j], q.keys[i]];
  if (q.pos === i) q.pos = j; else if (q.pos === j) q.pos = i;
  q.original = null; // ordre choisi à la main
  save();
  renderNow();
}

function removeFromQueue(i) {
  const q = S.queue;
  q.keys.splice(i, 1);
  if (i < q.pos) q.pos--;
  else if (i === q.pos) q.pos = Math.min(q.pos, q.keys.length - 1);
  q.original = null;
  save();
  renderNow();
}

function dedupe(keys) {
  const seen = new Set();
  return keys.filter((k) => {
    const d = dupKey(k);
    if (seen.has(d)) return false;
    seen.add(d);
    return true;
  });
}

// ============================================================ playlists

const plById = (id) => S.playlists.find((p) => p.id === id);

function createPlaylist(name) {
  const p = { id: uid(), name: name || 'Playlist sans titre', keys: [], markers: [] };
  S.playlists.push(p);
  save();
  return p;
}

function pruneMarkers(p) {
  const valid = new Set(p.keys);
  p.markers = (p.markers || []).filter((m) => m.after === null || valid.has(m.after));
}

function addToPlaylist(p, keys) {
  const before = p.keys.length;
  p.keys.push(...keys);
  save();
  toast(`${p.keys.length - before} morceau(x) ajouté(s) à « ${p.name} »`);
}

function moveInPlaylist(p, i, dir) {
  const j = i + dir;
  if (j < 0 || j >= p.keys.length) return;
  [p.keys[i], p.keys[j]] = [p.keys[j], p.keys[i]];
  save();
  renderPlaylists();
}

/** Moves a marker one slot up/down (slots: start, after track 1, after track 2…). */
function moveMarker(p, m, dir) {
  const slots = [null, ...p.keys];
  const cur = slots.indexOf(m.after);
  const n = cur + dir;
  if (n < 0 || n >= slots.length) return;
  m.after = slots[n];
  save();
  renderPlaylists();
}

function exportPlaylist(p) {
  const data = {
    boomPlayerPlaylist: 1,
    name: p.name,
    tracks: p.keys.map((k) => {
      const t = byKey.get(k);
      const m = meta(k);
      return {
        rawFilename: t ? t.rawFilename : k.split('|')[0],
        name: t ? t.pTitle : m.name || k,
        artist: t ? t.pArtist : m.artist || '',
        customTitle: m.customTitle, customArtist: m.customArtist,
        tags: m.tags || [], duration: m.duration,
      };
    }),
    markers: (p.markers || []).map((m) => ({
      after: m.after === null ? null : (byKey.get(m.after)?.rawFilename || m.after.split('|')[0]),
      label: m.label, color: m.color,
    })),
  };
  const name = `${p.name.replace(/[\\/:*?"<>|]/g, '_')}.json`;
  const content = JSON.stringify(data, null, 2);
  if (!bridge({ type: 'saveFile', name, content })) {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([content], { type: 'application/json' }));
    a.download = name;
    document.body.appendChild(a);
    a.click();
    a.remove();
  }
}

async function importPlaylistFile(file) {
  let data;
  try { data = JSON.parse(await file.text()); } catch (_) { toast('Fichier invalide'); return; }
  if (!data || !Array.isArray(data.tracks)) { toast('Format de playlist non reconnu'); return; }
  const keys = [];
  let missing = 0;
  for (const tr of data.tracks) {
    if (!tr || !tr.rawFilename) continue;
    const key = tr.rawFilename;
    if (!has(key)) missing++;
    const m = meta(key);
    const patch = {};
    for (const f of ['customTitle', 'customArtist', 'duration']) if (m[f] == null && tr[f] != null) patch[f] = tr[f];
    if (!has(key)) { patch.name = tr.customTitle || tr.mcTitle || tr.name || key; patch.artist = tr.customArtist || tr.mcArtist || tr.artist || ''; }
    if (Array.isArray(tr.tags) && tr.tags.length) patch.tags = [...new Set([...(m.tags || []), ...tr.tags])];
    if (Object.keys(patch).length) S.meta[key] = { ...m, ...patch };
    keys.push(key);
  }
  const p = createPlaylist(data.name || file.name.replace(/\.json$/i, ''));
  p.keys = keys;
  const known = new Set(keys);
  p.markers = (Array.isArray(data.markers) ? data.markers : [])
    .filter((m) => m && (m.after == null || known.has(m.after)))
    .map((m) => ({ id: uid(), after: m.after == null ? null : m.after, label: m.label || '', color: m.color || MARKER_COLORS[0] }));
  save();
  openPl = p.id;
  switchView('playlists');
  toast(`« ${p.name} » importée : ${keys.length} morceau(x)${missing ? `, ${missing} absent(s) du téléphone` : ''}`);
}

// ============================================================ library

const hasHub = () => location.protocol.startsWith('http');

async function loadLibrary(refresh = false) {
  if (!hasHub() || libLoading) return;
  libLoading = true;
  $('#libInfo').textContent = 'Recherche des musiques…';
  try {
    const res = await fetch(`/__hub/music${refresh ? '?refresh=1' : ''}`, { cache: 'no-store' });
    if (!res.ok) throw new Error(String(res.status));
    const data = await res.json();
    needPermission = !!data.needPermission;
    const imported = library.filter((t) => t.imported);
    library = (data.tracks || []).map((t) => makeTrack({
      rawFilename: t.file || `${t.name}${(t.path.match(/\.[^./]+$/) || [''])[0]}`,
      folder: t.folder,
      path: t.path,
      src: `/__hub/music/file?p=${encodeURIComponent(t.path)}`,
    })).concat(imported);
    indexLibrary();
    libLoaded = true;
    $('#permBox').classList.toggle('hidden', !needPermission);
    if (refresh && !needPermission) toast(`${library.length} morceau(x) trouvé(s)`);
  } catch (_) {
    $('#libInfo').textContent = 'Bibliothèque indisponible ici : importe tes fichiers.';
  } finally {
    libLoading = false;
    renderAll();
  }
}

function importFiles(files) {
  const added = [];
  for (const f of files) {
    if (!(f.type.startsWith('audio/') || /\.(mp3|m4a|aac|ogg|oga|opus|wav|flac|webm)$/i.test(f.name))) continue;
    const existing = byKey.get(f.name);
    if (existing && !existing.imported) { added.push(existing.key); continue; }
    const t = makeTrack({ rawFilename: f.name, folder: 'Importé (cette session)', src: URL.createObjectURL(f), imported: true });
    library.push(t);
    added.push(f.name);
  }
  indexLibrary();
  if (!added.length) { toast('Aucun fichier audio'); return; }
  renderAll();
  toast(`${added.length} fichier(s) prêt(s) — les playlists qui les attendaient les retrouvent`);
}

// ============================================================ sheets (menus & forms)

let sheetResolve = null;

function closeSheet(result = null) {
  $('#sheet').classList.add('hidden');
  $('#scrim').classList.add('hidden');
  const r = sheetResolve;
  sheetResolve = null;
  if (r) r(result);
}

function openSheet(html, onClick) {
  if (sheetResolve) closeSheet();
  $('#sheetBody').innerHTML = html;
  $('#sheet').classList.remove('hidden');
  $('#scrim').classList.remove('hidden');
  return new Promise((resolve) => {
    sheetResolve = resolve;
    $('#sheetBody').onclick = (e) => onClick && onClick(e);
  });
}

/** Action menu. Resolves with the chosen item's act, or null. */
function menu(title, sub, items) {
  const html = `<h3>${esc(title)}</h3>${sub ? `<div class="sub">${esc(sub)}</div>` : ''}
    ${items.map((it) => `<button class="item${it.danger ? ' danger' : ''}" data-act="${esc(it.act)}"><span class="ico">${it.ico || ''}</span>${esc(it.label)}</button>`).join('')}`;
  return openSheet(html, (e) => {
    const b = e.target.closest('[data-act]');
    if (b) closeSheet(b.dataset.act);
  });
}

/** Small form. fields: [{ id, label, value, placeholder }], color: initial color or undefined. */
function form(title, fields, { color, ok = 'OK', sub } = {}) {
  let chosen = color;
  const html = `<h3>${esc(title)}</h3>${sub ? `<div class="sub">${esc(sub)}</div>` : ''}
    ${fields.map((f) => `<label class="lbl" for="f_${f.id}">${esc(f.label)}</label>
      <input class="field" id="f_${f.id}" value="${esc(f.value || '')}" placeholder="${esc(f.placeholder || '')}" autocomplete="off">`).join('')}
    ${color !== undefined ? `<label class="lbl">Couleur</label><div class="swatches">${MARKER_COLORS.map((c) =>
      `<button class="swatch${c === color ? ' on' : ''}" data-color="${c}" style="background:${c}" aria-label="${c}"></button>`).join('')}</div>` : ''}
    <div class="actions"><button class="pill" data-act="cancel">Annuler</button><button class="pill accent" data-act="ok">${esc(ok)}</button></div>`;
  const p = openSheet(html, (e) => {
    const sw = e.target.closest('[data-color]');
    if (sw) {
      chosen = sw.dataset.color;
      $$('.swatch').forEach((s) => s.classList.toggle('on', s === sw));
      return;
    }
    const b = e.target.closest('[data-act]');
    if (!b) return;
    if (b.dataset.act === 'cancel') return closeSheet(null);
    const out = { color: chosen };
    fields.forEach((f) => { out[f.id] = $(`#f_${f.id}`).value.trim(); });
    closeSheet(out);
  });
  setTimeout(() => { const first = fields[0] && $(`#f_${fields[0].id}`); if (first) first.focus(); }, 250);
  $('#sheetBody').onkeydown = (e) => { if (e.key === 'Enter') { const okBtn = $('#sheetBody [data-act=ok]'); if (okBtn) okBtn.click(); } };
  return p;
}

async function choosePlaylist(keys) {
  const items = S.playlists.map((p) => ({ act: p.id, label: `${p.name} (${p.keys.length})`, ico: '🎶' }));
  items.unshift({ act: '__new', label: 'Nouvelle playlist…', ico: '＋' });
  const act = await menu('Ajouter à une playlist', `${keys.length} morceau(x)`, items);
  if (!act) return false;
  let p = plById(act);
  if (act === '__new') {
    const r = await form('Nouvelle playlist', [{ id: 'name', label: 'Nom', placeholder: 'Boom de la colo' }], { ok: 'Créer' });
    if (!r) return false;
    p = createPlaylist(r.name);
  }
  if (p) { addToPlaylist(p, keys); renderPlaylists(); }
  return !!p;
}

async function editTags(keys) {
  const common = keys.length === 1 ? tagsOf(keys[0]).join(', ') : '';
  const known = allTags();
  const r = await form(keys.length === 1 ? 'Balises' : `Balises (${keys.length} morceaux)`,
    [{ id: 'tags', label: 'Séparées par des virgules', value: common, placeholder: 'Bouge, Danse romantique, Rap' }],
    { sub: known.length ? `Existantes : ${known.join(', ')}` : 'Ex. « Bouge », « Calme », « Rap »' });
  if (!r) return;
  const list = r.tags.split(',').map((s) => s.trim()).filter(Boolean);
  for (const k of keys) {
    const tags = keys.length === 1 ? list : [...new Set([...tagsOf(k), ...list])];
    setMeta(k, { tags });
  }
  renderAll();
}

async function rename(key) {
  const r = await form('Renommer', [
    { id: 'title', label: 'Titre', value: titleOf(key) },
    { id: 'artist', label: 'Artiste', value: artistOf(key) },
  ], { sub: byKey.get(key)?.rawFilename || key });
  if (!r) return;
  const t = byKey.get(key);
  setMeta(key, {
    customTitle: r.title && r.title !== (t?.pTitle || meta(key).name) ? r.title : undefined,
    customArtist: r.artist && r.artist !== (t?.pArtist || meta(key).artist) ? r.artist : undefined,
  });
  renderAll();
  if (decks[active].key === key) updateMediaSession();
}

async function renamePlaylist(p) {
  const r = await form('Renommer la playlist', [{ id: 'name', label: 'Nom', value: p.name }]);
  if (!r || !r.name) return;
  p.name = r.name;
  save();
  renderPlaylists();
}

async function markerForm(p, m, after) {
  const r = await form(m ? 'Modifier le repère' : 'Nouveau repère',
    [{ id: 'label', label: 'Libellé (optionnel)', value: m ? m.label : '', placeholder: 'Calme, Ça bouge…' }],
    { color: m ? m.color : MARKER_COLORS[0], ok: m ? 'Enregistrer' : 'Ajouter' });
  if (!r) return;
  if (m) { m.label = r.label; m.color = r.color; } else p.markers.push({ id: uid(), after, label: r.label, color: r.color });
  save();
  renderPlaylists();
  renderNow();
}

async function trackMenu(key, ctxInfo = {}) {
  const items = [
    { act: 'play', label: 'Lire maintenant', ico: '▶' },
    { act: 'next', label: 'Lire ensuite', ico: '⤵' },
    { act: 'queue', label: 'Ajouter à la file', ico: '＋' },
    { act: 'playlist', label: 'Ajouter à une playlist…', ico: '🎶' },
    { act: 'tags', label: 'Balises…', ico: '🏷' },
    { act: 'rename', label: 'Renommer…', ico: '✎' },
  ];
  if (ctxInfo.pl) {
    items.push({ act: 'marker', label: 'Repère après ce morceau', ico: '🚩' });
    items.push({ act: 'remove', label: 'Retirer de la playlist', ico: '✕', danger: true });
  }
  const sub = [artistOf(key), has(key) ? byKey.get(key).folder : 'Absent de ce téléphone'].filter(Boolean).join(' · ');
  const act = await menu(titleOf(key), sub, items);
  switch (act) {
    case 'play': playQueue([key], 0); break;
    case 'next': enqueue([key], true); break;
    case 'queue': enqueue([key]); break;
    case 'playlist': choosePlaylist([key]); break;
    case 'tags': editTags([key]); break;
    case 'rename': rename(key); break;
    case 'marker': markerForm(ctxInfo.pl, null, key); break;
    case 'remove':
      ctxInfo.pl.keys.splice(ctxInfo.index, 1);
      pruneMarkers(ctxInfo.pl);
      save();
      renderPlaylists();
      break;
    default: break;
  }
}

function addMusicSheet() {
  const html = `<h3>🎵 Ajouter une musique</h3>
    <div class="sub">Télécharge ton MP3 : il arrive dans « Téléchargements ». Reviens ensuite ici et touche ↻ dans la bibliothèque, il y apparaîtra.</div>
    <a class="link" href="https://www.youtube.com" data-url="https://www.youtube.com">▶ 1 · Ouvrir YouTube</a>
    <a class="link" href="https://notube.lol/fr/youtube-app-419" data-url="https://notube.lol/fr/youtube-app-419">⬇ 2 · Ouvrir notube.lol (conversion MP3)</a>
    <div class="actions"><button class="pill" data-act="refresh">↻ Actualiser la bibliothèque</button><button class="pill accent" data-act="close">Fermer</button></div>`;
  openSheet(html, (e) => {
    const a = e.target.closest('[data-url]');
    if (a) {
      e.preventDefault();
      if (!bridge({ type: 'openUrl', url: a.dataset.url })) window.open(a.dataset.url, '_blank');
      return;
    }
    const b = e.target.closest('[data-act]');
    if (!b) return;
    closeSheet();
    if (b.dataset.act === 'refresh') { switchView('library'); loadLibrary(true); }
  });
}

// ============================================================ long press

function longPress(container, selector, fn) {
  let timer = null;
  let fired = false;
  let sx = 0;
  let sy = 0;
  container.addEventListener('pointerdown', (e) => {
    const el = e.target.closest(selector);
    if (!el || e.target.closest('button')) return;
    fired = false;
    sx = e.clientX;
    sy = e.clientY;
    clearTimeout(timer);
    timer = setTimeout(() => {
      fired = true;
      if (navigator.vibrate) navigator.vibrate(15);
      fn(el);
    }, 550);
  });
  container.addEventListener('pointermove', (e) => { if (Math.abs(e.clientX - sx) > 8 || Math.abs(e.clientY - sy) > 8) clearTimeout(timer); });
  ['pointerup', 'pointercancel', 'pointerleave'].forEach((t) => container.addEventListener(t, () => clearTimeout(timer)));
  container.addEventListener('click', (e) => { if (fired) { fired = false; e.stopPropagation(); e.preventDefault(); } }, true);
  container.addEventListener('contextmenu', (e) => { if (e.target.closest(selector)) e.preventDefault(); });
}

// ============================================================ rendering

const ICON_PLAY = '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>';
const ICON_PAUSE = '<svg viewBox="0 0 24 24"><path d="M6 5h4v14H6zm8 0h4v14h-4z"/></svg>';

function initials(key) {
  const words = titleOf(key).split(/\s+/).filter(Boolean);
  return (words.length > 1 ? words[0][0] + words[1][0] : (words[0] || '♪').slice(0, 2)).toUpperCase();
}

function applyAmbient(key) {
  const h = key ? hash(key) % 360 : 280;
  document.documentElement.style.setProperty('--amb-1', h);
  document.documentElement.style.setProperty('--amb-2', (h + 50) % 360);
}

function tagHtml(key) {
  return tagsOf(key).map((t) => `<span class="tag">${esc(t)}</span>`).join('');
}

function markerHtml(m, editable) {
  return `<li class="marker" style="--mc:${esc(m.color)}" data-marker="${esc(m.id)}">
    <span class="line"></span>${m.label ? `<span class="lbl">${esc(m.label)}</span><span class="line"></span>` : ''}
    ${editable ? `<button class="b" data-act="mup" aria-label="Monter le repère">▲</button>
    <button class="b" data-act="mdown" aria-label="Descendre le repère">▼</button>
    <button class="b" data-act="medit" aria-label="Modifier le repère">✎</button>
    <button class="b" data-act="mdel" aria-label="Supprimer le repère">✕</button>` : ''}
  </li>`;
}

function renderAll() {
  renderNow();
  renderLibrary();
  renderPlaylists();
  renderMini();
  renderSelBar();
}

function renderPlayState() {
  const playing = isPlaying(decks[active]);
  $('#playBtn').innerHTML = playing ? ICON_PAUSE : ICON_PLAY;
  $('#playBtn').setAttribute('aria-label', playing ? 'Pause' : 'Lecture');
  $('#miniPlay').innerHTML = playing ? ICON_PAUSE : ICON_PLAY;
  $('#npArt').classList.toggle('playing', playing);
  $$('#queueList .eq').forEach((e) => e.classList.toggle('paused', !playing));
  if ('mediaSession' in navigator) navigator.mediaSession.playbackState = playing ? 'playing' : 'paused';
}

function renderNow() {
  const key = decks[active].key || S.queue.keys[S.queue.pos];
  $('#npTitle').textContent = key ? titleOf(key) : 'Aucun morceau';
  $('#npArtist').textContent = key ? artistOf(key) : 'Choisis des musiques dans la bibliothèque';
  $('#npTags').innerHTML = key ? tagHtml(key) : '';
  $('#npInitials').textContent = key ? initials(key) : '♪';
  $('#fadeLabel').textContent = `${S.settings.fade} s`;
  $('#shuffleBtn').classList.toggle('on', S.settings.shuffle);
  $('#loopBtn').classList.toggle('on', S.settings.loop !== 'off');
  $('#loopBtn').classList.toggle('one', S.settings.loop === 'one');
  renderPlayState();

  // File d'attente, avec les repères de la playlist d'origine
  const q = S.queue;
  const pl = q.source && !S.settings.shuffle ? plById(q.source) : null;
  const markersAfter = (k) => (pl ? pl.markers.filter((m) => m.after === k) : []);
  const playing = isPlaying(decks[active]);
  let html = pl ? pl.markers.filter((m) => m.after === null).map((m) => markerHtml(m, false)).join('') : '';
  q.keys.forEach((k, i) => {
    const cur = i === q.pos;
    html += `<li class="row${cur ? ' current' : ''}${has(k) ? '' : ' missing'}" data-i="${i}">
      <span class="lead">${cur ? `<span class="eq${playing ? '' : ' paused'}"><i></i><i></i><i></i></span>` : i + 1}</span>
      <div class="txt" data-act="play"><div class="t1">${esc(titleOf(k))}</div><div class="t2">${esc(artistOf(k))}${tagsOf(k).length ? ' · ' + esc(tagsOf(k).join(' • ')) : ''}</div></div>
      <button class="b" data-act="up" aria-label="Monter">▲</button>
      <button class="b" data-act="down" aria-label="Descendre">▼</button>
      <button class="b" data-act="rm" aria-label="Retirer">✕</button>
    </li>`;
    html += markersAfter(k).map((m) => markerHtml(m, false)).join('');
  });
  $('#queueList').innerHTML = html;
  $('#queueEmpty').classList.toggle('hidden', q.keys.length > 0);
  const total = q.keys.reduce((s, k) => s + (meta(k).duration || 0), 0);
  $('#queueInfo').textContent = q.keys.length ? `${q.keys.length} morceau(x)${total ? ' · ' + mins(total) : ''}` : '';
  renderMini();
}

function renderMini() {
  const key = decks[active].key;
  const show = !!key && view !== 'now';
  $('#mini').classList.toggle('hidden', !show);
  document.documentElement.style.setProperty('--mini-h', show ? '66px' : '0px');
  if (!key) return;
  $('#miniTitle').textContent = titleOf(key);
  $('#miniArtist').textContent = artistOf(key);
  $('#miniArt').textContent = initials(key);
}

function libraryRows(list, startIndex = 0) {
  return list.map((t, i) => {
    const sel = selected.has(t.key);
    const d = meta(t.key).duration;
    return `<div class="row${sel ? ' selected' : ''}${decks[active].key === t.key ? ' current' : ''}" data-key="${esc(t.key)}" data-i="${startIndex + i}">
      ${selecting ? `<span class="check">${sel ? '✓' : ''}</span>` : ''}
      <div class="txt" data-act="tap"><div class="t1">${esc(titleOf(t.key))}</div>
        <div class="t2">${esc(artistOf(t.key))}${d ? ' · ' + fmt(d) : ''}</div>${tagHtml(t.key)}</div>
      ${selecting ? '' : '<button class="b" data-act="menu" aria-label="Options">⋮</button>'}
    </div>`;
  }).join('');
}

let libGroups = [];
let libFlat = [];

function renderLibrary() {
  const box = $('#libList');
  const q = norm($('#search').value);
  const base = visibleLibrary();
  // Filtre balises
  const tags = allTags(library.map((t) => t.key));
  if (libTag && !tags.includes(libTag)) libTag = null;
  $('#tagFilter').innerHTML = tags.length
    ? [`<button class="chip${libTag ? '' : ' on'}" data-tag="">Toutes</button>`, ...tags.map((t) => `<button class="chip${t === libTag ? ' on' : ''}" data-tag="${esc(t)}">🏷 ${esc(t)}</button>`)].join('')
    : '';
  let list = base;
  if (libTag) list = list.filter((t) => tagsOf(t.key).includes(libTag));
  if (q) list = list.filter((t) => norm(`${titleOf(t.key)} ${artistOf(t.key)} ${t.folder} ${tagsOf(t.key).join(' ')} ${t.rawFilename}`).includes(q));

  $('#selectBtn').classList.toggle('on', selecting);
  if (!needPermission && libLoaded) {
    const hidden = library.length - base.length;
    $('#libInfo').textContent = `${library.length} morceau(x)${hidden ? ` · ${hidden} doublon(s) masqué(s)` : ''}`;
  }
  $('#dedupInfo').textContent = S.settings.hideDupes ? `${library.length - base.length} doublon(s) masqué(s) (même titre et artiste)` : '';
  $('#dedupLibBtn').textContent = S.settings.hideDupes ? '👁 Afficher les doublons' : '🧹 Masquer les doublons';

  if (!list.length) {
    libGroups = [];
    libFlat = [];
    box.innerHTML = needPermission ? '' : `<div class="empty">${library.length ? 'Aucun résultat.' : (libLoading ? 'Recherche…' : 'Aucune musique trouvée.')}</div>`;
    return;
  }
  if (q || libTag) {
    libFlat = list;
    libGroups = [];
    const shown = list.slice(0, 400);
    box.innerHTML = `<div class="rows">${libraryRows(shown)}</div>${list.length > shown.length ? `<div class="empty">${list.length - shown.length} de plus : affine la recherche</div>` : ''}`;
    return;
  }
  libFlat = [];
  const groups = new Map();
  for (const t of list) {
    if (!groups.has(t.folder)) groups.set(t.folder, []);
    groups.get(t.folder).push(t);
  }
  const prevOpen = new Set($$('#libList details[open]').map((d) => d.dataset.name));
  libGroups = [...groups.entries()];
  const openAll = libGroups.length === 1;
  box.innerHTML = libGroups.map(([folder, items], gi) => {
    const open = openAll || prevOpen.has(folder);
    return `<details class="folder" data-g="${gi}" data-name="${esc(folder)}" ${open ? 'open' : ''}>
      <summary><span class="fname">📁 ${esc(folder)}</span><span class="muted">${items.length}</span>
        <button class="pill" data-act="playFolder">▶</button><button class="pill" data-act="folderMenu">⋮</button></summary>
      <div class="inner">${open ? libraryRows(items) : ''}</div>
    </details>`;
  }).join('');
}

function listForRow(rowEl) {
  const det = rowEl.closest('details[data-g]');
  if (det) return libGroups[+det.dataset.g][1];
  return libFlat;
}

function renderPlaylists() {
  const detail = openPl && plById(openPl);
  $('#plIndex').classList.toggle('hidden', !!detail);
  $('#plDetail').classList.toggle('hidden', !detail);
  if (!detail) {
    openPl = null;
    $('#plEmpty').classList.toggle('hidden', S.playlists.length > 0);
    $('#plList').innerHTML = S.playlists.map((p) => {
      const h = hash(p.id) % 360;
      const dur = p.keys.reduce((s, k) => s + (meta(k).duration || 0), 0);
      const miss = p.keys.filter((k) => !has(k)).length;
      return `<li class="row pl-row" data-pl="${esc(p.id)}">
        <span class="pl-ic" style="background:linear-gradient(135deg,hsl(${h},80%,55%),hsl(${(h + 50) % 360},85%,55%))">${esc((p.name[0] || '♪').toUpperCase())}</span>
        <div class="txt" data-act="open"><div class="t1">${esc(p.name)}</div>
          <div class="t2">${p.keys.length} morceau(x)${dur ? ' · ' + mins(dur) : ''}${miss && libLoaded ? ` · ${miss} absent(s)` : ''}${p.markers.length ? ` · ${p.markers.length} repère(s)` : ''}</div></div>
        <button class="b hot" data-act="play" aria-label="Lire">▶</button>
        <button class="b" data-act="menu" aria-label="Options">⋮</button>
      </li>`;
    }).join('');
    return;
  }
  const p = detail;
  pruneMarkers(p);
  $('#plTitle').textContent = p.name;
  const miss = p.keys.filter((k) => !has(k)).length;
  $('#plInfo').textContent = `${p.keys.length} morceau(x)${miss && libLoaded ? ` · ${miss} absent(s) du téléphone` : ''}`;
  const tags = allTags(p.keys);
  if (plTag && !tags.includes(plTag)) plTag = null;
  $('#plTagFilter').innerHTML = tags.length
    ? [`<button class="chip${plTag ? '' : ' on'}" data-tag="">Toutes</button>`, ...tags.map((t) => `<button class="chip${t === plTag ? ' on' : ''}" data-tag="${esc(t)}">🏷 ${esc(t)}</button>`)].join('')
    : '';
  const showMarkers = !plTag;
  let html = showMarkers ? p.markers.filter((m) => m.after === null).map((m) => markerHtml(m, true)).join('') : '';
  const seenAfter = new Set();
  p.keys.forEach((k, i) => {
    if (plTag && !tagsOf(k).includes(plTag)) return;
    const d = meta(k).duration;
    html += `<li class="row${has(k) ? '' : ' missing'}${decks[active].key === k ? ' current' : ''}" data-i="${i}" data-key="${esc(k)}">
      <span class="lead">${i + 1}</span>
      <div class="txt" data-act="play"><div class="t1">${esc(titleOf(k))}</div>
        <div class="t2">${esc(artistOf(k))}${d ? ' · ' + fmt(d) : ''}${has(k) ? '' : ' · absent du téléphone'}</div>${tagHtml(k)}</div>
      <button class="b" data-act="up" aria-label="Monter">▲</button>
      <button class="b" data-act="down" aria-label="Descendre">▼</button>
      <button class="b" data-act="flag" aria-label="Repère après">🚩</button>
      <button class="b" data-act="menu" aria-label="Options">⋮</button>
    </li>`;
    if (showMarkers && !seenAfter.has(k)) {
      seenAfter.add(k);
      html += p.markers.filter((m) => m.after === k).map((m) => markerHtml(m, true)).join('');
    }
  });
  $('#plTracks').innerHTML = html;
  $('#plTracksEmpty').classList.toggle('hidden', p.keys.length > 0);
}

function renderSelBar() {
  $('#selBar').classList.toggle('hidden', !selecting);
  $('#selCount').textContent = selected.size;
  const plBtn = $('#selBar [data-sel=playlist]');
  const target = selTarget && plById(selTarget);
  plBtn.textContent = target ? `＋ ${target.name}` : '＋ Playlist';
}

function renderSettings() {
  const s = S.settings;
  $('#fadeRange').value = s.fade;
  $('#fadeVal').textContent = `${s.fade} s`;
  $('#autoChk').checked = s.auto;
  $('#skipChk').checked = s.fadeSkip;
  $('#pauseChk').checked = s.fadePause;
  $('#ambientChk').checked = s.ambient;
  document.body.classList.toggle('no-ambient', !s.ambient);
  $('#volRange').value = s.volume;
  $('#volVal').textContent = `${Math.round(s.volume * 100)} %`;
  $$('#curveSeg button').forEach((b) => b.classList.toggle('active', b.dataset.v === s.curve));
  const pts = (fn) => Array.from({ length: 41 }, (_, i) => `${(i * 2.5).toFixed(1)},${(38 - fn(i / 40) * 36).toFixed(1)}`).join(' ');
  $('#curvePreview').innerHTML = `<path d="M${pts((t) => shape(1 - t))}" stroke="#ff4fa3"/><path d="M${pts(shape)}" stroke="#b45cff"/>`;
  $$('input[type=range]').forEach(paintRange);
  $('#fadeLabel').textContent = `${s.fade} s`;
}

function paintRange(r) {
  const min = +r.min || 0;
  const max = +r.max || 1;
  r.style.setProperty('--p', `${((r.value - min) / (max - min)) * 100}%`);
}

let seeking = false;
function tick() {
  const d = decks[active];
  const dur = d.el.duration;
  const ratio = isFinite(dur) && dur > 0 ? d.el.currentTime / dur : 0;
  if (!seeking) {
    const seek = $('#seek');
    seek.value = Math.round(ratio * 1000);
    paintRange(seek);
  }
  $('#cur').textContent = fmt(d.el.currentTime);
  $('#dur').textContent = fmt(dur);
  $('#miniBar').style.width = `${ratio * 100}%`;
  const lvl = (k) => (decks[k].key && !decks[k].el.paused ? gainOf(decks[k]) : 0);
  $('#mixA').style.width = `${Math.round(lvl(0) * 100)}%`;
  $('#mixB').style.width = `${Math.round(lvl(1) * 100)}%`;
  requestAnimationFrame(tick);
}

function updateMediaSession() {
  if (!('mediaSession' in navigator)) return;
  const k = decks[active].key;
  try {
    navigator.mediaSession.metadata = k ? new MediaMetadata({ title: titleOf(k), artist: artistOf(k), album: 'Boom Player' }) : null;
  } catch (_) { /* non supporté */ }
}

function switchView(v) {
  view = v;
  $$('.tabs button').forEach((b) => b.classList.toggle('active', b.dataset.view === v));
  $$('.view').forEach((s) => s.classList.toggle('hidden', s.id !== `view-${v}`));
  if (v === 'library' && !libLoaded) loadLibrary();
  if (v === 'playlists') renderPlaylists();
  if (v !== 'library' && selecting && !selTarget) exitSelect();
  renderMini();
  window.scrollTo(0, 0);
}

function exitSelect() {
  selecting = false;
  selTarget = null;
  selected.clear();
  renderLibrary();
  renderSelBar();
}

// ============================================================ events

function bind() {
  $$('.tabs button').forEach((b) => b.addEventListener('click', () => switchView(b.dataset.view)));
  $$('[data-goto]').forEach((b) => b.addEventListener('click', () => switchView(b.dataset.goto)));
  $('#addMusicBtn').addEventListener('click', addMusicSheet);
  $('#scrim').addEventListener('click', () => closeSheet());

  // Transport
  $('#playBtn').addEventListener('click', togglePlay);
  $('#miniPlay').addEventListener('click', togglePlay);
  $('#nextBtn').addEventListener('click', goNext);
  $('#miniNext').addEventListener('click', goNext);
  $('#prevBtn').addEventListener('click', goPrev);
  $('#miniOpen').addEventListener('click', () => switchView('now'));
  $('#fadeNowBtn').addEventListener('click', () => {
    const n = nextPos();
    if (n < 0) return toast('Rien à enchaîner');
    crossfadeTo(n, S.settings.fade);
  });
  $('#shuffleBtn').addEventListener('click', () => setShuffle(!S.settings.shuffle));
  $('#loopBtn').addEventListener('click', () => {
    S.settings.loop = { all: 'one', one: 'off', off: 'all' }[S.settings.loop];
    save();
    renderNow();
    toast({ all: 'Répéter tout', one: 'Répéter ce morceau', off: 'Sans répétition' }[S.settings.loop]);
  });
  const seek = $('#seek');
  seek.addEventListener('input', () => { seeking = true; paintRange(seek); });
  seek.addEventListener('change', () => {
    const el = decks[active].el;
    if (isFinite(el.duration)) el.currentTime = (seek.value / 1000) * el.duration;
    seeking = false;
  });

  // File d'attente
  $('#queueList').addEventListener('click', (e) => {
    const b = e.target.closest('[data-act]');
    const li = e.target.closest('li[data-i]');
    if (!b || !li) return;
    const i = +li.dataset.i;
    if (b.dataset.act === 'play') { if (has(S.queue.keys[i])) crossfadeTo(i, skipDur()); else toast('Fichier absent de ce téléphone'); }
    if (b.dataset.act === 'up') moveInQueue(i, -1);
    if (b.dataset.act === 'down') moveInQueue(i, 1);
    if (b.dataset.act === 'rm') removeFromQueue(i);
  });
  longPress($('#queueList'), 'li[data-i] .txt', (el) => rename(S.queue.keys[+el.closest('li').dataset.i]));
  $('#queueClearBtn').addEventListener('click', async () => {
    if (!S.queue.keys.length) return;
    const act = await menu('Vider la file d\'attente ?', 'Le morceau en cours continue.', [{ act: 'yes', label: 'Vider', ico: '🗑', danger: true }]);
    if (act !== 'yes') return;
    const cur = decks[active].key;
    S.queue = { keys: cur ? [cur] : [], pos: cur ? 0 : -1, source: null, original: null };
    save();
    renderNow();
  });
  $('#queueDedupBtn').addEventListener('click', () => {
    const q = S.queue;
    const cur = q.keys[q.pos];
    const before = q.keys.length;
    q.keys = dedupe(q.keys);
    q.pos = cur ? Math.max(0, q.keys.indexOf(cur)) : -1;
    q.original = null;
    save();
    renderNow();
    toast(`${before - q.keys.length} doublon(s) retiré(s)`);
  });

  // Bibliothèque
  let searchTimer = null;
  $('#search').addEventListener('input', () => { clearTimeout(searchTimer); searchTimer = setTimeout(renderLibrary, 150); });
  $('#refreshBtn').addEventListener('click', () => loadLibrary(true));
  $('#rescanBtn').addEventListener('click', () => { switchView('library'); loadLibrary(true); });
  $('#importFiles').addEventListener('change', (e) => { importFiles(e.target.files); e.target.value = ''; });
  $('#grantBtn').addEventListener('click', () => {
    if (!bridge({ type: 'requestMusicPermission' })) toast('Ouvre Boom Player depuis Mes Projets');
  });
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && needPermission) loadLibrary(true);
  });
  $('#tagFilter').addEventListener('click', (e) => {
    const c = e.target.closest('[data-tag]');
    if (!c) return;
    libTag = c.dataset.tag || null;
    renderLibrary();
  });
  $('#playAllBtn').addEventListener('click', () => {
    const list = libFlat.length ? libFlat : visibleLibrary();
    playQueue(list.map((t) => t.key), 0);
  });
  $('#selectBtn').addEventListener('click', () => { if (selecting) exitSelect(); else { selecting = true; renderLibrary(); renderSelBar(); } });
  $('#dedupLibBtn').addEventListener('click', () => { S.settings.hideDupes = !S.settings.hideDupes; save(); renderLibrary(); });

  const lib = $('#libList');
  lib.addEventListener('toggle', (e) => {
    const det = e.target;
    if (det.tagName !== 'DETAILS' || !det.open) return;
    const inner = det.querySelector('.inner');
    if (!inner.innerHTML.trim()) inner.innerHTML = libraryRows(libGroups[+det.dataset.g][1]);
  }, true);
  lib.addEventListener('click', async (e) => {
    const b = e.target.closest('[data-act]');
    const det = e.target.closest('details[data-g]');
    if (selecting && !b?.dataset.act?.startsWith('playFolder') && e.target.closest('[data-key]')) {
      const row = e.target.closest('[data-key]');
      const k = row.dataset.key;
      if (selected.has(k)) selected.delete(k); else selected.add(k);
      row.classList.toggle('selected', selected.has(k));
      row.querySelector('.check').textContent = selected.has(k) ? '✓' : '';
      renderSelBar();
      return;
    }
    if (!b) return;
    if (b.dataset.act === 'playFolder' || b.dataset.act === 'folderMenu') {
      e.preventDefault();
      const items = libGroups[+det.dataset.g][1].map((t) => t.key);
      if (b.dataset.act === 'playFolder') { playQueue(items, 0); return; }
      const act = await menu(libGroups[+det.dataset.g][0], `${items.length} morceau(x)`, [
        { act: 'play', label: 'Lire le dossier', ico: '▶' },
        { act: 'shuffle', label: 'Lire en aléatoire', ico: '🔀' },
        { act: 'queue', label: 'Ajouter à la file', ico: '＋' },
        { act: 'playlist', label: 'Ajouter à une playlist…', ico: '🎶' },
        { act: 'tags', label: 'Baliser tout le dossier…', ico: '🏷' },
      ]);
      if (act === 'play') playQueue(items, 0);
      if (act === 'shuffle') playQueue(items, 0, null, true);
      if (act === 'queue') enqueue(items);
      if (act === 'playlist') choosePlaylist(items);
      if (act === 'tags') editTags(items);
      return;
    }
    const row = e.target.closest('[data-key]');
    if (!row) return;
    const key = row.dataset.key;
    if (b.dataset.act === 'menu') { trackMenu(key); return; }
    if (b.dataset.act === 'tap') {
      const list = listForRow(row).map((t) => t.key);
      playQueue(list, Math.max(0, list.indexOf(key)));
    }
  });
  longPress(lib, '[data-key] .txt', (el) => { if (!selecting) rename(el.closest('[data-key]').dataset.key); });

  // Barre de sélection
  $('#selBar').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-sel]');
    if (!b) return;
    const keys = library.filter((t) => selected.has(t.key)).map((t) => t.key);
    if (b.dataset.sel === 'cancel') { const back = selTarget; exitSelect(); if (back) { openPl = back; switchView('playlists'); } return; }
    if (!keys.length) { toast('Sélectionne des morceaux'); return; }
    if (b.dataset.sel === 'queue') { enqueue(keys); exitSelect(); }
    if (b.dataset.sel === 'tag') { await editTags(keys); }
    if (b.dataset.sel === 'playlist') {
      const target = selTarget && plById(selTarget);
      if (target) {
        addToPlaylist(target, keys);
        exitSelect();
        openPl = target.id;
        switchView('playlists');
        renderPlaylists();
      } else if (await choosePlaylist(keys)) exitSelect();
    }
  });

  // Playlists
  $('#newPlBtn').addEventListener('click', async () => {
    const r = await form('Nouvelle playlist', [{ id: 'name', label: 'Nom', placeholder: 'Boom de la colo' }], { ok: 'Créer' });
    if (!r) return;
    const p = createPlaylist(r.name);
    openPl = p.id;
    renderPlaylists();
  });
  $('#importPlInput').addEventListener('change', (e) => { const f = e.target.files[0]; e.target.value = ''; if (f) importPlaylistFile(f); });
  $('#plList').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-act]');
    const li = e.target.closest('[data-pl]');
    if (!b || !li) return;
    const p = plById(li.dataset.pl);
    if (b.dataset.act === 'open') { openPl = p.id; plTag = null; renderPlaylists(); window.scrollTo(0, 0); }
    if (b.dataset.act === 'play') playQueue(p.keys, 0, p.id);
    if (b.dataset.act === 'menu') playlistMenu(p);
  });
  longPress($('#plList'), '[data-pl] .txt', (el) => renamePlaylist(plById(el.closest('[data-pl]').dataset.pl)));
  $('#plBackBtn').addEventListener('click', () => { openPl = null; renderPlaylists(); });
  $('#plMenuBtn').addEventListener('click', () => playlistMenu(plById(openPl)));
  $('#plPlayBtn').addEventListener('click', () => { const p = plById(openPl); playQueue(p.keys, 0, p.id); });
  $('#plShuffleBtn').addEventListener('click', () => { const p = plById(openPl); playQueue(p.keys, 0, p.id, true); });
  $('#plAddBtn').addEventListener('click', () => {
    selTarget = openPl;
    selecting = true;
    selected.clear();
    switchView('library');
    renderLibrary();
    renderSelBar();
    toast('Coche les morceaux puis « ＋ ' + plById(openPl).name + ' »');
  });
  $('#plStartMarkerBtn').addEventListener('click', () => markerForm(plById(openPl), null, null));
  $('#plTitle').addEventListener('click', () => renamePlaylist(plById(openPl)));
  $('#plTagFilter').addEventListener('click', (e) => {
    const c = e.target.closest('[data-tag]');
    if (!c) return;
    plTag = c.dataset.tag || null;
    renderPlaylists();
  });
  $('#plTracks').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-act]');
    if (!b) return;
    const p = plById(openPl);
    const mk = e.target.closest('[data-marker]');
    if (mk) {
      const m = p.markers.find((x) => x.id === mk.dataset.marker);
      if (!m) return;
      if (b.dataset.act === 'mup') moveMarker(p, m, -1);
      if (b.dataset.act === 'mdown') moveMarker(p, m, 1);
      if (b.dataset.act === 'medit') markerForm(p, m);
      if (b.dataset.act === 'mdel') { p.markers = p.markers.filter((x) => x !== m); save(); renderPlaylists(); renderNow(); }
      return;
    }
    const li = e.target.closest('li[data-i]');
    if (!li) return;
    const i = +li.dataset.i;
    const key = p.keys[i];
    switch (b.dataset.act) {
      case 'play': if (has(key)) playQueue(p.keys, i, p.id); else toast('Fichier absent : ajoute-le au téléphone (même nom de fichier)'); break;
      case 'up': moveInPlaylist(p, i, -1); break;
      case 'down': moveInPlaylist(p, i, 1); break;
      case 'flag': markerForm(p, null, key); break;
      case 'menu': trackMenu(key, { pl: p, index: i }); break;
      default: break;
    }
  });
  longPress($('#plTracks'), 'li[data-i] .txt', (el) => rename(plById(openPl).keys[+el.closest('li').dataset.i]));

  // Réglages
  const s = S.settings;
  $('#fadeRange').addEventListener('input', (e) => { s.fade = +e.target.value; renderSettings(); save(); });
  $('#autoChk').addEventListener('change', (e) => { s.auto = e.target.checked; save(); });
  $('#skipChk').addEventListener('change', (e) => { s.fadeSkip = e.target.checked; save(); });
  $('#pauseChk').addEventListener('change', (e) => { s.fadePause = e.target.checked; save(); });
  $('#ambientChk').addEventListener('change', (e) => { s.ambient = e.target.checked; renderSettings(); save(); });
  $('#volRange').addEventListener('input', (e) => {
    s.volume = +e.target.value;
    if (master) master.gain.setTargetAtTime(s.volume, ctx.currentTime, 0.02);
    else decks.forEach((d) => { if (d === decks[active]) d.el.volume = s.volume; });
    renderSettings();
    save();
  });
  $('#curveSeg').addEventListener('click', (e) => {
    const b = e.target.closest('[data-v]');
    if (!b) return;
    s.curve = b.dataset.v;
    renderSettings();
    save();
  });

  if ('mediaSession' in navigator) {
    const set = (a, fn) => { try { navigator.mediaSession.setActionHandler(a, fn); } catch (_) { /* non supporté */ } };
    set('play', () => { if (!isPlaying(decks[active])) togglePlay(); });
    set('pause', () => { if (isPlaying(decks[active])) togglePlay(); });
    set('nexttrack', goNext);
    set('previoustrack', goPrev);
  }
}

async function playlistMenu(p) {
  if (!p) return;
  const act = await menu(p.name, `${p.keys.length} morceau(x)`, [
    { act: 'play', label: 'Lire', ico: '▶' },
    { act: 'shuffle', label: 'Lire en aléatoire', ico: '🔀' },
    { act: 'queue', label: 'Ajouter à la file', ico: '＋' },
    { act: 'rename', label: 'Renommer…', ico: '✎' },
    { act: 'dedup', label: 'Supprimer les doublons', ico: '🧹' },
    { act: 'export', label: 'Exporter (.json)', ico: '⤓' },
    { act: 'delete', label: 'Supprimer la playlist', ico: '🗑', danger: true },
  ]);
  switch (act) {
    case 'play': playQueue(p.keys, 0, p.id); break;
    case 'shuffle': playQueue(p.keys, 0, p.id, true); break;
    case 'queue': enqueue(p.keys); break;
    case 'rename': renamePlaylist(p); break;
    case 'dedup': {
      const before = p.keys.length;
      p.keys = dedupe(p.keys);
      pruneMarkers(p);
      save();
      renderPlaylists();
      toast(`${before - p.keys.length} doublon(s) supprimé(s)`);
      break;
    }
    case 'export': exportPlaylist(p); break;
    case 'delete': {
      const ok = await menu(`Supprimer « ${p.name} » ?`, 'Les fichiers musicaux ne sont pas touchés.', [{ act: 'yes', label: 'Supprimer', ico: '🗑', danger: true }]);
      if (ok !== 'yes') return;
      S.playlists = S.playlists.filter((x) => x !== p);
      if (openPl === p.id) openPl = null;
      save();
      renderPlaylists();
      break;
    }
    default: break;
  }
}

// ============================================================ start

restore();
bind();
renderSettings();
applyAmbient(S.queue.keys[S.queue.pos]);
renderAll();
requestAnimationFrame(tick);
loadLibrary().then(() => { if (!S.queue.keys.length && !S.playlists.length) switchView('library'); });

// Pour déboguer depuis l'inspecteur de la WebView.
window.__boom = { get S() { return S; }, decks, get active() { return active; }, crossfadeTo, playQueue, gainOf, byKey };
