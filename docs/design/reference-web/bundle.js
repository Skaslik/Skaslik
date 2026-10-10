/* @ds-bundle: {"format":4,"namespace":"MS","components":[{"name":"Room"},{"name":"Candle"},{"name":"ScreenHome"},{"name":"ScreenCalendar"},{"name":"ScreenFiles"},{"name":"ScreenTogether"},{"name":"ScreenUs"},{"name":"ScreenLoyaltyCard"},{"name":"ScreenLock"},{"name":"TabBar"},{"name":"Chips"},{"name":"Button"},{"name":"SyncStatus"},{"name":"EventRow"},{"name":"FileRow"},{"name":"PiggyBank"},{"name":"PairStats"}]} */
/*
 * МС — preview helpers. Static HTML/SVG renderers used by the component
 * previews. The real components are Flutter widgets (ms_app/lib/design_system);
 * these functions only draw the agreed look. No network, no React.
 */
(function () {
  var uid = 0;
  function nextId(p) { uid += 1; return p + uid; }

  /* ---------- icons: Material Symbols Rounded ---------- */
  function icon(name, opts) {
    opts = opts || {};
    var cls = 'ms-ic' + (opts.fill ? ' ms-ic--fill' : '') + (opts.cls ? ' ' + opts.cls : '');
    var st = opts.size ? ' style="font-size:' + opts.size + 'px"' : '';
    return '<span class="' + cls + '"' + st + ' aria-hidden="true">' + name + '</span>';
  }

  /* ---------- the Basenji (black & white), facing left, lying ---------- */
  /* local box ~ 0..170 x -14..106; origin = left end of the front paws' baseline */
  function basenji() {
    return '' +
      '<g class="dog">' +
      /* tail: tight curl over the hip, white tip */
      '<path class="d-coat-stroke" d="M146 50 C136 40 140 26 152 26 C164 26 168 40 158 46 C152 50 146 46 148 40" />' +
      '<circle class="d-white" cx="148.5" cy="40" r="3.6" />' +
      /* body with a smooth nape-to-back line */
      '<path class="d-coat" d="M52 58 C50 46 52 36 58 30 C66 24 75 24 79 28 C86 35 96 38 110 38 C130 38 152 46 157 68 C160 86 150 104 124 104 L66 104 C50 104 42 94 42 80 C42 70 46 63 52 58 Z" />' +
      /* hind thigh volume */
      '<path class="d-shade" d="M112 66 C130 60 150 68 152 84 C154 98 140 104 124 104 L104 104 C100 92 100 74 112 66 Z" />' +
      /* hind paw, tucked forward */
      '<path class="d-white" d="M92 98 C100 95 114 95 120 98 C124 100 124 105 119 106 L94 106 C89 106 88 100 92 98 Z" />' +
      /* far front leg (shade) */
      '<path class="d-shade" d="M50 88 L20 89 C13 89 12 96 18 97 L52 97 Z" />' +
      /* white throat + chest, one shape */
      '<path class="d-white" d="M49 42 C45 52 45 66 47 78 C49 90 55 99 65 102 C62 90 62 72 66 58 C61 54 57 49 56 42 Z" />' +
      /* near front leg, white, extended toward the window */
      '<path class="d-white" d="M64 94 L22 95 C12 95 10 105 19 106 L66 106 C72 106 72 95 64 94 Z" />' +
      '<path class="d-toe" d="M24 101 L24 105.5 M29 101 L29 105.5" />' +
      /* far ear */
      '<path class="d-shade" d="M52 8 L56 -14 L64 6 Z" />' +
      /* head: domed skull, muzzle tapering to the left */
      '<path class="d-coat" d="M78 24 C78 12 68 4 56 4 C46 4 38 9 33 15 C30 19 26 22 20 25 C14 28 9 31 9 35 C9 39 14 41 22 41 L40 42 C54 43 68 40 75 34 C78 31 79 28 78 24 Z" />' +
      /* near ear + inner */
      '<path class="d-coat" d="M60 10 L67 -17 C68 -20 71 -20 72 -17 L80 17 Z" />' +
      '<path class="d-ear" d="M64.5 7 L68.5 -11 L75 13 Z" />' +
      /* white muzzle front and chin; a thin blaze up the bridge to the stop */
      '<path class="d-white" d="M12.5 36.5 C13 40 18 41.6 26 42 C32 42.3 37 42 40 41 C36 39 30 37.6 24 36.2 C19 35.2 15 35 12.5 36.5 Z" />' +
      '<path class="d-white" d="M15.5 30.2 C21 27.6 27 23.8 33 18.8 C34.2 17.8 35.6 18.6 34.8 19.8 C29.4 25.2 23 29.6 17.2 32.2 Z" />' +
      /* nose */
      '<ellipse class="d-nose" cx="10.5" cy="34" rx="3.4" ry="2.8" />' +
      /* eye: almond, lighter than the coat so it reads */
      '<path class="d-eye" d="M39 23 C42 19.5 48 19 51 21.5 C48 24.6 42 25.2 39 23 Z" />' +
      '<circle class="d-white" cx="47.4" cy="21.2" r="1" />' +
      /* forehead wrinkles */
      '<path class="d-wrinkle" d="M52 11 C55 9.4 58 9.6 60.5 11 M51 14.6 C54 13 57 13.2 59.6 14.4" />' +
      '</g>';
  }

  /* ---------- the armchair (front view) with the dog on its cushion ---------- */
  function armchair() {
    return '' +
      '<g class="chair">' +
      '<ellipse class="s-shadow" cx="89" cy="168" rx="96" ry="9" />' +
      '<rect class="s-wood" x="16" y="150" width="9" height="18" rx="3" />' +
      '<rect class="s-wood" x="153" y="150" width="9" height="18" rx="3" />' +
      '<rect class="s-fabric" x="16" y="0" width="146" height="110" rx="34" />' +
      '<path class="s-fabric-shade" d="M30 18 C40 10 60 8 89 8 C118 8 138 10 148 18" />' +
      '<rect class="s-fabric-shade" x="0" y="64" width="36" height="92" rx="17" />' +
      '<rect class="s-fabric-shade" x="142" y="64" width="36" height="92" rx="17" />' +
      '<rect class="s-fabric-light" x="26" y="92" width="126" height="40" rx="14" />' +
      '<rect class="s-fabric-shade" x="10" y="126" width="158" height="28" rx="10" />' +
      '<g transform="translate(24 9) scale(0.86)">' + basenji() + '</g>' +
      '</g>';
  }

  /* ---------- window contents: sky + weather ---------- */
  function sky(w, gid) {
    var time = w.time || 'night';
    var top = time === 'day' ? 'var(--sky-day)' : 'var(--sky-night)';
    var low = time === 'day' ? 'var(--sky-day-low)' : 'var(--sky-night-low)';
    if (time === 'day' && (w.kind === 'rain' || w.kind === 'cloudy')) { top = 'var(--sky-overcast)'; low = 'var(--sky-day-low)'; }
    return '<linearGradient id="' + gid + '" x1="0" y1="0" x2="0" y2="1">' +
      '<stop offset="0" style="stop-color:' + top + '"/><stop offset="1" style="stop-color:' + low + '"/></linearGradient>';
  }

  function weatherMarks(w, x, y, wd, ht) {
    var k = w.kind || 'clear', s = '', i;
    var night = (w.time || 'night') !== 'day';
    if (k === 'clear' && night) {
      s += '<circle class="w-mark" cx="' + (x + wd - 30) + '" cy="' + (y + 26) + '" r="11" />';
      s += '<circle style="fill:url(#' + w._gid + ')" cx="' + (x + wd - 25) + '" cy="' + (y + 22) + '" r="10" />';
      var stars = [[0.12, 0.62], [0.3, 0.8], [0.55, 0.7], [0.8, 0.6], [0.66, 0.88], [0.2, 0.92], [0.9, 0.82]];
      for (i = 0; i < stars.length; i++) s += '<circle class="w-mark" cx="' + (x + stars[i][0] * wd) + '" cy="' + (y + stars[i][1] * ht) + '" r="1.1" />';
    } else if (k === 'clear') {
      s += '<circle class="w-sun" cx="' + (x + wd - 30) + '" cy="' + (y + 28) + '" r="13" />';
    }
    if (k === 'cloudy' || k === 'rain' || k === 'snow') {
      s += '<g class="w-cloud"><ellipse cx="' + (x + wd - 34) + '" cy="' + (y + 20) + '" rx="26" ry="9"/><ellipse cx="' + (x + wd - 46) + '" cy="' + (y + 14) + '" rx="14" ry="9"/>' +
        '<ellipse cx="' + (x + 20) + '" cy="' + (y + ht * 0.9) + '" rx="30" ry="8"/></g>';
    }
    if (k === 'rain') {
      for (i = 0; i < 26; i++) {
        var rx = x + ((i * 37) % wd), ry = y + 30 + ((i * 53) % (ht - 30));
        s += '<line class="w-rain" x1="' + rx + '" y1="' + ry + '" x2="' + (rx - 4) + '" y2="' + (ry + 11) + '" />';
      }
    }
    if (k === 'snow') {
      for (i = 0; i < 30; i++) {
        var sx = x + ((i * 41) % wd), sy = y + 26 + ((i * 29) % (ht - 26));
        s += '<circle class="w-mark" cx="' + sx + '" cy="' + sy + '" r="' + (1.2 + (i % 3) * 0.5) + '" />';
      }
    }
    return s;
  }

  /* ---------- candle (in scene coordinates; base at 0,0) ---------- */
  function candleGlyph(state, gid, glowR) {
    var lit = state === 'lit' || state === 'pending';
    var s = '<g class="candle' + (lit ? ' is-lit' : '') + '">';
    if (lit) {
      s += '<radialGradient id="' + gid + '"><stop offset="0" style="stop-color:var(--flame-glow)"/><stop offset="1" style="stop-color:var(--flame-glow);stop-opacity:0"/></radialGradient>';
      s += '<circle cx="0" cy="-44" r="' + (glowR || 78) + '" style="fill:url(#' + gid + ')" />';
    }
    s += '<ellipse class="s-shadow" cx="0" cy="0" rx="14" ry="2.5" />';
    s += '<rect class="c-wax" x="-8" y="-32" width="16" height="32" rx="3" />';
    s += '<path class="c-drip" d="M-8 -28 C-8 -24 -5 -24 -5 -20 C-5 -18 -3 -18 -3 -21 L-3 -30 Z" />';
    s += '<ellipse class="c-top" cx="0" cy="-32" rx="8" ry="2" />';
    s += '<line class="c-wick" x1="0" y1="-33" x2="0" y2="-38" />';
    if (lit) {
      s += '<g class="c-flame-g"><path class="c-flame" d="M0 -58 C5 -50 7 -44 5 -40 C3.5 -37 -3.5 -37 -5 -40 C-7 -44 -5 -50 0 -58 Z" />' +
        '<path class="c-core" d="M0 -48 C2 -45 2.6 -42 1.6 -40.4 C1 -39.6 -1 -39.6 -1.6 -40.4 C-2.6 -42 -2 -45 0 -48 Z" /></g>';
    } else {
      s += '<path class="c-smoke" d="M0 -40 C3 -45 -3 -49 0 -54 C3 -58 -1 -62 1 -66" />';
    }
    s += '<rect class="hit" x="-26" y="-74" width="52" height="80" />';
    return s + '</g>';
  }

  /*
   * roomSVG(opts)
   *  weather: {kind:'rain'|'snow'|'clear'|'cloudy', time:'night'|'day', temp:'+7°', label:'мелкий дождь', place:'Москва'}
   *  candle:  'off' | 'lit' | 'pending'
   *  note:    {text:'Купи хлеб', by:'michael'|'sofia', sign:'М.'}
   *  logo:    URL of the monogram image for the picture frame (optional)
   */
  function roomSVG(o) {
    o = o || {};
    var w = o.weather || { kind: 'rain', time: 'night', temp: '+7°', label: 'мелкий дождь', place: 'Москва' };
    var gSky = nextId('msSky'), gGlow = nextId('msGlow'), gClip = nextId('msGlass'), gVig = nextId('msVig');
    w._gid = gSky;
    var night = (w.time || 'night') !== 'day';
    var inkCls = night ? 'w-ink-night' : 'w-ink-day';
    var gx = 48, gy = 78, gw = 136, gh = 172;
    var s = '<svg class="ms-scene" viewBox="0 0 390 440" preserveAspectRatio="xMidYMid slice" role="img" aria-label="Комната: окно, свеча на подоконнике, басенджи на кресле">';
    s += '<defs>' + sky(w, gSky) +
      '<clipPath id="' + gClip + '"><rect x="' + gx + '" y="' + gy + '" width="' + gw + '" height="' + gh + '" rx="3"/></clipPath>' +
      '<radialGradient id="' + gVig + '" cx="0.42" cy="0.55" r="0.75"><stop offset="0.55" style="stop-color:var(--scene-shadow);stop-opacity:0"/><stop offset="1" style="stop-color:var(--scene-shadow)"/></radialGradient>' +
      '</defs>';
    /* wall, wainscot, floor */
    s += '<rect class="s-wall" x="0" y="0" width="390" height="440" />';
    s += '<rect class="s-wall-low" x="0" y="300" width="390" height="62" />';
    s += '<rect class="s-wood-dark" x="0" y="298" width="390" height="3" />';
    s += '<rect class="s-floor" x="0" y="362" width="390" height="78" />';
    s += '<rect class="s-wood-dark" x="0" y="360" width="390" height="4" />';
    s += '<ellipse class="s-rug" cx="292" cy="404" rx="118" ry="22" />';
    /* picture frame with the monogram */
    s += '<g class="frame"><rect class="s-wood" x="282" y="70" width="70" height="70" rx="3" />';
    if (o.logo) {
      s += '<image href="' + o.logo + '" x="288" y="76" width="58" height="58" preserveAspectRatio="xMidYMid slice" />';
    } else {
      s += '<rect class="s-note" x="288" y="76" width="58" height="58" />';
    }
    s += '<rect class="hit" x="276" y="64" width="82" height="82" /></g>';
    /* the note on the wall */
    if (o.note !== null) {
      var n = o.note || { text: 'Купи хлеб', by: 'michael', sign: 'М.' };
      s += '<g class="note" transform="rotate(-5 250 164)">' +
        '<rect class="s-shadow" x="218" y="140" width="64" height="48" rx="2" transform="translate(1.5 2)" />' +
        '<rect class="s-note" x="218" y="140" width="64" height="48" rx="2" />' +
        '<circle class="pin pin--' + (n.by === 'sofia' ? 'sofia' : 'michael') + '" cx="250" cy="145" r="3" />' +
        '<text class="note-txt" x="250" y="164" text-anchor="middle">' + esc(n.text) + '</text>' +
        '<text class="note-sign" x="275" y="180" text-anchor="end">— ' + esc(n.sign || '') + '</text>' +
        '<rect class="hit" x="212" y="134" width="76" height="60" /></g>';
    }
    /* curtain rod + curtains */
    s += '<rect class="s-wood-dark" x="14" y="52" width="206" height="4" rx="2" />';
    s += '<circle class="s-wood" cx="14" cy="54" r="5" /><circle class="s-wood" cx="220" cy="54" r="5" />';
    /* window */
    s += '<rect class="s-wood" x="' + (gx - 10) + '" y="' + (gy - 10) + '" width="' + (gw + 20) + '" height="' + (gh + 20) + '" rx="5" />';
    s += '<g clip-path="url(#' + gClip + ')"><rect x="' + gx + '" y="' + gy + '" width="' + gw + '" height="' + gh + '" style="fill:url(#' + gSky + ')" />' +
      weatherMarks(w, gx, gy, gw, gh) + '</g>';
    /* weather, written outside */
    s += '<g class="weather ' + inkCls + '">' +
      '<text class="w-temp" x="' + (gx + 12) + '" y="' + (gy + 44) + '">' + esc(w.temp || '') + '</text>' +
      '<text class="w-label" x="' + (gx + 13) + '" y="' + (gy + 62) + '">' + esc(w.label || '') + '</text>' +
      '<text class="w-place" x="' + (gx + 13) + '" y="' + (gy + 76) + '">' + esc((w.place || '').toUpperCase()) + '</text>' +
      '</g>';
    /* mullions: one transom bar + a center bar below it */
    s += '<rect class="s-wood" x="' + gx + '" y="' + (gy + 102) + '" width="' + gw + '" height="6" />';
    s += '<rect class="s-wood" x="' + (gx + gw / 2 - 3) + '" y="' + (gy + 102) + '" width="6" height="' + (gh - 102) + '" />';
    s += '<rect class="hit" x="' + gx + '" y="' + gy + '" width="' + gw + '" height="96" />';
    /* curtains over the frame edges */
    s += '<path class="s-curtain" d="M18 56 L50 56 C46 120 52 200 44 268 C38 300 30 300 22 304 C26 240 16 140 18 56 Z" />';
    s += '<path class="s-curtain-shade" d="M28 60 C27 130 30 220 27 300 M38 60 C38 140 42 220 37 296" />';
    s += '<path class="s-curtain" d="M184 56 L216 56 C218 140 208 240 212 304 C204 300 196 300 190 268 C182 200 188 120 184 56 Z" />';
    s += '<path class="s-curtain-shade" d="M206 60 C207 130 204 220 207 300 M196 60 C196 140 192 220 197 296" />';
    /* sill */
    s += '<rect class="s-wood-dark" x="30" y="268" width="174" height="7" rx="2" />';
    s += '<rect class="s-wood" x="26" y="260" width="182" height="9" rx="2" />';
    /* plant */
    s += '<g class="plant"><path class="s-plant" d="M70 236 C60 226 56 214 60 204 C66 212 70 222 72 234 Z M74 234 C74 220 80 208 90 202 C90 214 84 226 76 236 Z M72 236 C66 228 54 226 46 230 C54 236 64 238 72 238 Z" />' +
      '<path class="s-pot" d="M60 238 L84 238 L81 260 L63 260 Z" /><rect class="s-pot" x="58" y="235" width="28" height="5" rx="1.5" /></g>';
    /* candle on the sill */
    s += '<g transform="translate(152 260)" data-candle>' + candleGlyph(o.candle || 'lit', gGlow) + '</g>';
    /* armchair + basenji */
    s += '<g transform="translate(206 212)">' + armchair() + '</g>';
    /* evening vignette */
    if (o.vignette !== false) s += '<rect class="vig" x="0" y="0" width="390" height="440" style="fill:url(#' + gVig + ')" />';
    return s + '</svg>';
  }

  /* small standalone candle icon (status rows, notification art) */
  function candleIcon(state, size) {
    var g = nextId('msCg');
    var w = size || 40;
    return '<svg class="ms-scene ms-candle-ic" style="width:' + w + 'px;height:' + Math.round(w * 1.6) + 'px" viewBox="-30 -78 60 96" aria-hidden="true">' + candleGlyph(state, g, 30) + '</svg>';
  }

  /* ---------- EAN-13 ---------- */
  var L = ['0001101', '0011001', '0010011', '0111101', '0100011', '0110001', '0101111', '0111011', '0110111', '0001011'];
  var G = ['0100111', '0110011', '0011011', '0100001', '0011101', '0111001', '0000101', '0010001', '0001001', '0010111'];
  var R = ['1110010', '1100110', '1101100', '1000010', '1011100', '1001110', '1010000', '1000100', '1001000', '1110100'];
  var PAR = ['LLLLLL', 'LLGLGG', 'LLGGLG', 'LLGGGL', 'LGLLGG', 'LGGLLG', 'LGGGLL', 'LGLGLG', 'LGLGGL', 'LGGLGL'];
  function ean13Check(d12) {
    var s = 0;
    for (var i = 0; i < 12; i++) s += (+d12[i]) * (i % 2 ? 3 : 1);
    return (10 - (s % 10)) % 10;
  }
  function ean13(code12, height) {
    var d = code12.slice(0, 12) + ean13Check(code12);
    var bits = '101', p = PAR[+d[0]], i;
    for (i = 1; i <= 6; i++) bits += (p[i - 1] === 'L' ? L : G)[+d[i]];
    bits += '01010';
    for (i = 7; i <= 12; i++) bits += R[+d[i]];
    bits += '101';
    var h = height || 120, x, out = '';
    for (x = 0; x < bits.length; x++) {
      if (bits[x] === '1') {
        var guard = x < 3 || (x >= 45 && x < 50) || x >= 92;
        out += '<rect x="' + x + '" y="0" width="1" height="' + (guard ? h + 8 : h) + '"/>';
      }
    }
    return { digits: d, svg: '<svg class="ms-ean" viewBox="-9 0 113 ' + (h + 8) + '" preserveAspectRatio="none" role="img" aria-label="Штрихкод ' + d + '">' + out + '</svg>' };
  }

  /* ---------- chrome ---------- */
  function statusBar(time) {
    return '<div class="ms-statusbar"><span class="t">' + (time || '21:14') + '</span><span class="r">' +
      icon('signal_cellular_alt', { size: 16 }) + icon('wifi', { size: 16 }) + icon('battery_5_bar', { size: 16 }) + '</span></div>';
  }

  var TABS = [
    { id: 'home', label: 'Дом', ic: 'cottage' },
    { id: 'calendar', label: 'Календарь', ic: 'calendar_month' },
    { id: 'files', label: 'Файлы', ic: 'folder_open' },
    { id: 'together', label: 'Вместе', ic: 'join_inner' },
    { id: 'us', label: 'Мы', ic: 'favorite' }
  ];
  function tabBar(active, badges) {
    badges = badges || {};
    var s = '<nav class="ms-tabbar" aria-label="Разделы">';
    for (var i = 0; i < TABS.length; i++) {
      var t = TABS[i], on = t.id === active;
      s += '<a class="ms-tab' + (on ? ' is-on' : '') + '"' + (on ? ' aria-current="page"' : '') + '>' +
        '<span class="ms-tab__pill">' + icon(t.ic, { fill: on }) + (badges[t.id] ? '<i class="ms-tab__dot"></i>' : '') + '</span>' +
        '<span class="ms-tab__label">' + t.label + '</span></a>';
    }
    return s + '</nav>';
  }

  function pair(size) {
    return '<span class="ms-pair" style="--sz:' + (size || 28) + 'px" aria-label="Михаил и София"><i class="m"></i><i class="s"></i></span>';
  }

  function esc(t) { return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }

  window.MS = {
    icon: icon,
    roomSVG: roomSVG,
    candleIcon: candleIcon,
    ean13: ean13,
    statusBar: statusBar,
    tabBar: tabBar,
    pair: pair,
    esc: esc,
    TABS: TABS
  };
})();
