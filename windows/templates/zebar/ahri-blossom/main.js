// Spirit Blossom Ahri - Zebar bar logic (vanilla JS, no framework).
// The zebar client API is vendored in ./lib/zebar.mjs so the bar works offline at login.
import * as zebar from './lib/zebar.mjs';

const $ = id => document.getElementById(id);

// Nerd Font glyphs (Maple Mono NF).
const GLYPH = {
  play: '\u{F040A}',
  pause: '\u{F03E4}',
  ethernet: '\u{F0200}',
  vpn: '\u{F0CCC}',
  wifi4: '\u{F0928}',
  wifi3: '\u{F0925}',
  wifi2: '\u{F0922}',
  wifi1: '\u{F091F}',
  wifi0: '\u{F092F}',
  offline: '\u{F092E}',
  volHigh: '\u{F057E}',
  volMed: '\u{F0580}',
  volLow: '\u{F057F}',
  volMute: '\u{F075F}',
};

// ---------------------------------------------------------------- helpers

function run(program, args = []) {
  zebar.shellExec(program, args).catch(err => console.error(`[ahri] ${program} failed:`, err));
}

function ps(command) {
  run('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', command]);
}

const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, v));

function setText(el, text) {
  if (el.textContent !== text) el.textContent = text;
}

function level(el, value, warn, crit) {
  el.classList.toggle('warn', value >= warn && value < crit);
  el.classList.toggle('crit', value >= crit);
}

function fmtRate(bytes) {
  if (!Number.isFinite(bytes) || bytes < 1) return '0B';
  const units = ['B', 'K', 'M', 'G'];
  let i = 0;
  while (bytes >= 1000 && i < units.length - 1) {
    bytes /= 1000;
    i++;
  }
  return (bytes < 10 && i > 0 ? bytes.toFixed(1) : Math.round(bytes)) + units[i];
}

// Stop the webview's own context menu everywhere; right-click is ours.
document.addEventListener('contextmenu', e => e.preventDefault());

// ---------------------------------------------------------------- start / power

$('sigil').addEventListener('click', () =>
  ps("(New-Object -ComObject WScript.Shell).SendKeys('^{ESC}')"),
);

$('power').addEventListener('click', () =>
  ps('(New-Object -ComObject Shell.Application).ShutdownWindows()'),
);
$('power').addEventListener('contextmenu', () => run('rundll32.exe', ['user32.dll,LockWorkStation']));

// ---------------------------------------------------------------- clock

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const pad = n => String(n).padStart(2, '0');

function tickClock() {
  const d = new Date();
  setText($('time'), `${pad(d.getHours())}:${pad(d.getMinutes())}`);
  setText($('date'), `${DAYS[d.getDay()]} ${d.getDate()} ${MONTHS[d.getMonth()]}`);
}
tickClock();
// A short interval (instead of one long timeout) stays correct after sleep/resume.
setInterval(tickClock, 5000);

$('clock').addEventListener('click', () => run('explorer.exe', ['ms-actioncenter:']));

// ---------------------------------------------------------------- cpu / memory

const cpu = zebar.createProvider({ type: 'cpu', refreshInterval: 3000 });
cpu.onOutput(o => {
  const v = Math.round(o.usage);
  setText($('cpu-val'), `${v}%`);
  level($('cpu-val'), v, 80, 95);
});

const memory = zebar.createProvider({ type: 'memory', refreshInterval: 4000 });
memory.onOutput(o => {
  const v = Math.round(o.usage);
  setText($('mem-val'), `${v}%`);
  level($('mem-val'), v, 85, 95);
  $('mem').title = `Memory ${(o.usedMemory / 1e9).toFixed(1)} / ${(o.totalMemory / 1e9).toFixed(1)} GB - click for Task Manager`;
});

for (const id of ['cpu', 'mem']) $(id).addEventListener('click', () => run('taskmgr.exe'));

// ---------------------------------------------------------------- network

const network = zebar.createProvider({ type: 'network', refreshInterval: 3000 });
network.onOutput(o => {
  const iface = o.defaultInterface;
  const gw = o.defaultGateway;
  let icon = GLYPH.offline;
  let label = 'Offline';

  if (iface) {
    switch (iface.type) {
      case 'ethernet':
        icon = GLYPH.ethernet;
        label = 'Ethernet';
        break;
      case 'proprietary_virtual':
      case 'tunnel':
        icon = GLYPH.vpn;
        label = 'VPN';
        break;
      case 'wifi': {
        const s = gw?.signalStrength ?? 0;
        icon = s >= 80 ? GLYPH.wifi4 : s >= 60 ? GLYPH.wifi3 : s >= 40 ? GLYPH.wifi2 : s >= 20 ? GLYPH.wifi1 : GLYPH.wifi0;
        label = `Wi-Fi ${gw?.ssid ?? ''} (${s}%)`;
        break;
      }
      default:
        icon = GLYPH.ethernet;
        label = iface.friendlyName ?? 'Connected';
    }
  }

  setText($('net-ico'), icon);
  $('net').classList.toggle('offline', !iface);
  setText($('net-down'), fmtRate(o.traffic?.received?.bytes));
  setText($('net-up'), fmtRate(o.traffic?.transmitted?.bytes));
  $('net').title = `${label} - click for quick settings`;
});

$('net').addEventListener('click', () =>
  run('explorer.exe', ['ms-actioncenter:controlcenter/&showFooter=true']),
);

// ---------------------------------------------------------------- volume

const audio = zebar.createProvider({ type: 'audio' });
let volume = null; // optimistic local value while scrolling

function renderVolume(dev) {
  const vol = $('vol');
  if (!dev) {
    setText($('vol-val'), '--');
    return;
  }
  const v = Math.round(volume ?? dev.volume);
  const muted = dev.isMuted || v === 0;
  setText($('vol-val'), `${v}%`);
  setText($('vol-ico'), muted ? GLYPH.volMute : v >= 60 ? GLYPH.volHigh : v >= 25 ? GLYPH.volMed : GLYPH.volLow);
  vol.classList.toggle('muted', muted);
  vol.title = `${dev.name}\nScroll: volume - Click: mute - Right-click: mixer`;
}

audio.onOutput(o => {
  volume = null;
  renderVolume(o.defaultPlaybackDevice);
});

$('vol').addEventListener(
  'wheel',
  e => {
    const dev = audio.output?.defaultPlaybackDevice;
    if (!dev) return;
    const step = e.deltaY < 0 ? 2 : -2;
    volume = clamp(Math.round((volume ?? dev.volume) + step), 0, 100);
    renderVolume(dev);
    audio.output.setVolume(volume).catch(console.error);
  },
  { passive: true },
);

$('vol').addEventListener('click', () => {
  const dev = audio.output?.defaultPlaybackDevice;
  if (dev) audio.output.setMute(!dev.isMuted).catch(console.error);
});

$('vol').addEventListener('contextmenu', () => run('explorer.exe', ['ms-settings:apps-volume']));

// ---------------------------------------------------------------- media

const media = zebar.createProvider({ type: 'media' });
const mediaEl = $('media');
let mediaState = null; // { session, receivedAt }
let progressTimer = null;

const fmtDur = sec => `${Math.floor(sec / 60)}:${pad(Math.floor(sec % 60))}`;

function renderProgress() {
  if (!mediaState) return;
  const { session, receivedAt } = mediaState;
  const length = session.endTime - session.startTime;
  if (length <= 0) return;
  const elapsed = session.isPlaying ? (Date.now() - receivedAt) / 1000 : 0;
  const pos = clamp(session.position + elapsed - session.startTime, 0, length);
  setText($('media-time'), `${fmtDur(pos)} / ${fmtDur(length)}`);
}

function setMediaText(session) {
  const el = $('media-text');
  const title = session.title || 'Unknown';
  const artist = session.artist || '';
  const key = `${title}\u0000${artist}`;
  if (el.dataset.key === key) return;
  el.dataset.key = key;
  el.replaceChildren();
  const t = document.createElement('span');
  t.className = 'title';
  t.textContent = title;
  el.append(t);
  if (artist) {
    const dash = document.createElement('span');
    dash.className = 'dash';
    dash.textContent = '–';
    const a = document.createElement('span');
    a.className = 'artist';
    a.textContent = artist;
    el.append(dash, a);
  }
  el.title = artist ? `${title} – ${artist}` : title;
}

media.onOutput(o => {
  const session = o.currentSession;
  if (!session || (!session.title && !session.artist)) {
    mediaState = null;
    mediaEl.dataset.state = 'idle';
    clearInterval(progressTimer);
    progressTimer = null;
    return;
  }

  mediaState = { session, receivedAt: Date.now() };
  mediaEl.dataset.state = 'active';
  mediaEl.dataset.playing = String(session.isPlaying);
  mediaEl.dataset.hasTimeline = String(session.endTime > session.startTime);
  setMediaText(session);
  setText($('media-toggle'), session.isPlaying ? GLYPH.pause : GLYPH.play);
  renderProgress();

  // Only tick while something is actually playing.
  if (session.isPlaying && !progressTimer) {
    progressTimer = setInterval(renderProgress, 1000);
  } else if (!session.isPlaying && progressTimer) {
    clearInterval(progressTimer);
    progressTimer = null;
  }
});

function mediaCall(fn) {
  const out = media.output;
  const sessionId = out?.currentSession?.sessionId;
  if (out && sessionId) out[fn]({ sessionId });
}

$('media-prev').addEventListener('click', () => mediaCall('previous'));
$('media-toggle').addEventListener('click', () => mediaCall('togglePlayPause'));
$('media-next').addEventListener('click', () => mediaCall('next'));

// ---------------------------------------------------------------- systray

const systray = zebar.createProvider({ type: 'systray' });
const trayEl = $('tray');
const trayIcons = new Map(); // id -> element

function trayCall(fn, id) {
  const out = systray.output;
  if (out) out[fn](id).catch(err => console.error(`[ahri] systray ${fn}:`, err));
}

function makeTrayIcon(id) {
  const el = document.createElement('div');
  el.className = 'tray-icon';
  const img = document.createElement('img');
  img.alt = '';
  img.draggable = false;
  el.append(img);
  el.addEventListener('click', () => trayCall('onLeftClick', id));
  el.addEventListener('dblclick', () => trayCall('onLeftDoubleClick', id));
  el.addEventListener('contextmenu', () => trayCall('onRightClick', id));
  el.addEventListener('auxclick', e => {
    if (e.button === 1) trayCall('onMiddleClick', id);
  });
  el.addEventListener('mouseenter', () => trayCall('onHoverEnter', id));
  el.addEventListener('mouseleave', () => trayCall('onHoverLeave', id));
  return el;
}

systray.onOutput(o => {
  const seen = new Set();
  o.icons.forEach((icon, index) => {
    seen.add(icon.id);
    let el = trayIcons.get(icon.id);
    if (!el) {
      el = makeTrayIcon(icon.id);
      trayIcons.set(icon.id, el);
    }
    const img = el.firstChild;
    if (img.src !== icon.iconUrl) img.src = icon.iconUrl;
    if (el.title !== icon.tooltip) el.title = icon.tooltip;
    if (trayEl.children[index] !== el) trayEl.insertBefore(el, trayEl.children[index] ?? null);
  });
  for (const [id, el] of trayIcons) {
    if (!seen.has(id)) {
      el.remove();
      trayIcons.delete(id);
    }
  }
});
systray.onError(err => console.error('[ahri] systray:', err));

// Helper scripts live in ./scripts (see the comments there). The privilege regex in
// zpack.json only allows exactly these two files inside the installed pack folder.
const packDir = zebar.currentWidget().htmlPath.replace(/[\\/][^\\/]+$/, '');
const scriptArgs = name => [
  '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', `${packDir}\\scripts\\${name}.ps1`,
];

// guard.ps1: works around two Zebar 3.3.1 / Windows issues for the lifetime of the bar:
//  - the tray spy broadcasts `TaskbarCreated` before it wins the `Shell_TrayWnd` lookup, so
//    most apps re-register with Explorer instead; the guard re-broadcasts it once the spy is up.
//  - Explorer here ignores SHAppBarMessage (dockToEdge), so the guard reserves the top 52px
//    of the work area itself and re-applies it if Explorer resets it.
zebar.shellSpawn('powershell.exe', scriptArgs('guard'))
  .then(proc => proc.onExit(status => console.warn('[ahri] guard exited', status)))
  .catch(err => console.error('[ahri] guard failed:', err));

// Right-click the tray chevron to ask apps to re-add their icons (e.g. after an app restart).
$('tray-toggle').addEventListener('contextmenu', () => run('powershell.exe', scriptArgs('tray-refresh')));

function setTrayCollapsed(collapsed) {
  trayEl.classList.toggle('collapsed', collapsed);
  $('tray-toggle').classList.toggle('collapsed', collapsed);
}
// Always start expanded: the tray must never be hidden by a stale toggle.
$('tray-toggle').addEventListener('click', () => setTrayCollapsed(!trayEl.classList.contains('collapsed')));
