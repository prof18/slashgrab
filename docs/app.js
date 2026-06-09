/* Slashgrab landing page — interactive widgets, vanilla JS, no dependencies.
   Powers (1) the menu-bar drag demo and (2) the path-format switcher.
   Everything else on the page is static HTML; if this script fails the page
   still reads fine. */
(function () {
  'use strict';

  /* ---- the Slashgrab "token" glyph, three states (viewBox 0 0 22 22) ---- */
  var GLYPH = {
    idle: '<rect x="2.6" y="5.6" width="16.8" height="10.8" rx="2.6" fill="none" stroke="currentColor" stroke-width="1.7"/><line x1="8.9" y1="13.9" x2="13.1" y2="8.1" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
    active: '<rect x="2.6" y="5.6" width="16.8" height="10.8" rx="2.6" fill="none" stroke="currentColor" stroke-width="1.9"/><line x1="8.9" y1="13.9" x2="13.1" y2="8.1" stroke="currentColor" stroke-width="2.7" stroke-linecap="round"/>',
    success: '<rect x="2.6" y="5.6" width="16.8" height="10.8" rx="2.6" fill="none" stroke="currentColor" stroke-width="1.7"/><polyline points="8.3,11.2 10.1,13.2 13.9,8.4" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>'
  };

  /* ---- file/folder glyphs for the draggable desktop items ---- */
  function fileGlyph(kind, size) {
    if (kind === 'folder') {
      return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 52 52" fill="none" aria-hidden="true">' +
        '<path d="M4 14 h14 l4 4 h26 a3 3 0 0 1 3 3 v22 a3 3 0 0 1-3 3 H7 a3 3 0 0 1-3-3 V14z" fill="#7cc0ff"/>' +
        '<path d="M4 19 h44 a3 3 0 0 1 3 3 v22 a3 3 0 0 1-3 3 H7 a3 3 0 0 1-3-3 V19z" fill="#4ea3ff"/></svg>';
    }
    if (kind === 'locked') {
      return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 52 52" fill="none" aria-hidden="true">' +
        '<path d="M11 4 h21 l9 9 v33 a3 3 0 0 1-3 3 H11 a3 3 0 0 1-3-3 V7 a3 3 0 0 1 3-3z" fill="#cfd3da"/>' +
        '<path d="M32 4 v9 h9z" fill="#a9aeb8"/>' +
        '<rect x="19" y="27" width="14" height="11" rx="2" fill="#6b7280"/>' +
        '<path d="M22 27 v-3 a4 4 0 0 1 8 0 v3" stroke="#6b7280" stroke-width="2" fill="none"/></svg>';
    }
    return '<svg width="' + size + '" height="' + size + '" viewBox="0 0 52 52" fill="none" aria-hidden="true">' +
      '<path d="M11 4 h21 l9 9 v33 a3 3 0 0 1-3 3 H11 a3 3 0 0 1-3-3 V7 a3 3 0 0 1 3-3z" fill="#ffffff"/>' +
      '<path d="M32 4 v9 h9z" fill="#c8ccd4"/>' +
      '<rect x="15" y="22" width="22" height="2.4" rx="1.2" fill="#cdd2db"/>' +
      '<rect x="15" y="28" width="22" height="2.4" rx="1.2" fill="#cdd2db"/>' +
      '<rect x="15" y="34" width="14" height="2.4" rx="1.2" fill="#cdd2db"/></svg>';
  }

  var CHECK_DOT = '<svg class="t-dot" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 8.5 L6.5 11.5 L12.5 4.5"/></svg>';
  var BAN_DOT = '<svg class="t-dot" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2"><circle cx="8" cy="8" r="6"/><path d="M4 4 L12 12" stroke-linecap="round"/></svg>';

  /* =====================================================================
     1) MENU-BAR DRAG DEMO
     ===================================================================== */
  function initDemo() {
    var stage = document.getElementById('demo-stage');
    var statusItem = document.getElementById('demo-statusitem');
    var glyph = document.getElementById('demo-glyph');
    var menubar = document.getElementById('demo-menubar');
    var hint = document.getElementById('demo-hint');
    var filesWrap = document.getElementById('demo-files');
    if (!stage || !statusItem || !glyph || !filesWrap) return;

    var FILES = [
      { id: 'pdf', kind: 'file', name: 'Q3-Report.pdf', path: '~/Documents/Q3-Report.pdf' },
      { id: 'folder', kind: 'folder', name: 'project-atlas', path: '~/Developer/project-atlas' },
      { id: 'img', kind: 'file', name: 'hero@2x.png', path: '~/Design/exports/hero@2x.png' }
    ];

    /* build the draggable file icons */
    FILES.forEach(function (f) {
      var el = document.createElement('div');
      el.className = 'fileitem' + (f.locked ? ' locked' : '');
      el.innerHTML = '<div class="ic">' + fileGlyph(f.kind, 52) + '</div><div class="nm">' + f.name + '</div>';
      el.addEventListener('pointerdown', function (e) { startDrag(f, el, e); });
      filesWrap.appendChild(el);
    });

    var resetTimer = null, toast = null, ghost = null;
    var dragItem = null, dragEl = null, overIcon = false;

    function setState(state) {
      // state: idle | armed | success | reject
      statusItem.className = 'statusitem' +
        (state === 'armed' ? ' armed' : '') +
        (state === 'success' ? ' success' : '') +
        (state === 'reject' ? ' reject' : '');
      var g = state === 'success' ? 'success' :
              (state === 'armed' || state === 'reject') ? 'active' : 'idle';
      glyph.innerHTML = GLYPH[g];
    }

    function clearReset() { if (resetTimer) { clearTimeout(resetTimer); resetTimer = null; } }

    /* Center under the status item; slide inward only when the box would overflow. */
    function positionToast(el) {
      var s = stage.getBoundingClientRect();
      var i = statusItem.getBoundingClientRect();
      var w = el.offsetWidth;
      var margin = 10;
      var anchorX = i.left - s.left + i.width / 2;
      var leftEdge = anchorX - w / 2;
      if (leftEdge + w > s.width - margin) leftEdge = s.width - margin - w;
      if (leftEdge < margin) leftEdge = margin;
      el.style.left = (leftEdge + w / 2) + 'px';
    }

    function showToast(kind, path) {
      if (toast && toast.parentNode) toast.parentNode.removeChild(toast);
      toast = document.createElement('div');
      toast.className = 'toast' + (kind === 'bad' ? ' bad' : '');
      toast.innerHTML = '<div class="t-row">' + (kind === 'bad' ? BAN_DOT : CHECK_DOT) +
        (kind === 'bad' ? 'Couldn’t copy path' : 'Path copied') + '</div>' +
        '<div class="t-path">' + path + '</div>';
      stage.appendChild(toast);
      positionToast(toast);
      var mine = toast;
      setTimeout(function () { if (mine && mine.parentNode) mine.parentNode.removeChild(mine); if (toast === mine) toast = null; }, 1700);
    }

    function fireSuccess(item) {
      setState('success');
      showToast('ok', item.path);
      clearReset();
      resetTimer = setTimeout(function () { setState('idle'); }, 820);
    }
    function fireReject() {
      setState('reject');
      showToast('bad', 'Permission denied');
      clearReset();
      resetTimer = setTimeout(function () { setState('idle'); }, 520);
    }

    function hitIcon(x, y, pad) {
      pad = pad || 7;
      var r = statusItem.getBoundingClientRect();
      return x >= r.left - pad && x <= r.right + pad && y >= r.top - pad && y <= r.bottom + pad;
    }

    function onMove(e) {
      if (!dragItem) return;
      var x = e.clientX, y = e.clientY;
      if (ghost) { ghost.style.left = x + 'px'; ghost.style.top = y + 'px'; }
      if (hitIcon(x, y)) {
        overIcon = true;
        setState(dragItem.locked ? 'reject' : 'armed');
      } else {
        overIcon = false;
        setState('idle');
      }
    }

    function onUp() {
      window.removeEventListener('pointermove', onMove);
      window.removeEventListener('pointerup', onUp);
      if (ghost && ghost.parentNode) ghost.parentNode.removeChild(ghost);
      ghost = null;
      if (dragEl) dragEl.style.opacity = '1';
      if (hint) hint.style.opacity = '1';
      var item = dragItem, hit = overIcon;
      dragItem = null; dragEl = null; overIcon = false;
      if (item && hit) {
        if (item.locked) fireReject(); else fireSuccess(item);
      } else {
        setState('idle');
      }
    }

    function startDrag(item, el, e) {
      e.preventDefault();
      dragItem = item; dragEl = el; overIcon = false;
      el.style.opacity = '0.28';
      if (hint) hint.style.opacity = '0';
      ghost = document.createElement('div');
      ghost.className = 'drag-ghost' + (item.locked ? ' locked' : '');
      ghost.style.left = e.clientX + 'px';
      ghost.style.top = e.clientY + 'px';
      ghost.innerHTML = fileGlyph(item.kind, 46) + '<span class="nm">' + item.name + '</span>';
      document.body.appendChild(ghost);
      window.addEventListener('pointermove', onMove);
      window.addEventListener('pointerup', onUp);
    }
  }

  /* =====================================================================
     2) PATH-FORMAT SWITCHER
     ===================================================================== */
  function initFormats() {
    var list = document.getElementById('fmt-list');
    var outText = document.getElementById('fmt-out-text');
    var note = document.getElementById('fmt-note');
    var copyBtn = document.getElementById('fmt-copy');
    if (!list || !outText || !note || !copyBtn) return;

    var FORMATS = {
      shell: { name: 'Shell Escaped', out: '/Users/marco/Design/Q3\\ Report.pdf', note: 'Spaces and special characters are backslash-escaped, so it pastes straight into a shell command.' },
      path: { name: 'Path', out: '/Users/marco/Design/Q3 Report.pdf', note: 'Exactly as the filesystem sees it — nothing added, nothing escaped.' },
      quoted: { name: 'Quoted Path', out: '"/Users/marco/Design/Q3 Report.pdf"', note: 'Drop it into a command or config without worrying about spaces.' },
      url: { name: 'File URL', out: 'file:///Users/marco/Design/Q3%20Report.pdf', note: 'Percent-encoded file URL for browsers, configs and APIs.' },
      home: { name: 'Home-relative Path', out: '~/Design/Q3 Report.pdf', note: 'Compact and portable — your home directory becomes a tilde.' }
    };

    var copyResetTimer = null;
    var COPY_ICON = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M16 5l3 3-8 8-3-3z"/><path d="M5 19l3-1-2-2z"/><path d="M14 7l3 3"/></svg>';
    var TICK_ICON = '<svg width="13" height="13" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3.5 8.5l3 3 6-7"/></svg>';

    function select(key) {
      var f = FORMATS[key];
      if (!f) return;
      var opts = list.querySelectorAll('.fmt-opt');
      for (var i = 0; i < opts.length; i++) {
        opts[i].classList.toggle('on', opts[i].getAttribute('data-key') === key);
      }
      outText.textContent = f.out;
      note.innerHTML = '<b>' + f.name + '.</b> ' + f.note;
      // reset copy button
      copyBtn.classList.remove('done');
      copyBtn.innerHTML = COPY_ICON + 'Copy';
      if (copyResetTimer) { clearTimeout(copyResetTimer); copyResetTimer = null; }
    }

    list.addEventListener('click', function (e) {
      var btn = e.target.closest ? e.target.closest('.fmt-opt') : null;
      if (btn) select(btn.getAttribute('data-key'));
    });

    copyBtn.addEventListener('click', function () {
      var text = outText.textContent;
      try { if (navigator.clipboard) navigator.clipboard.writeText(text); } catch (err) {}
      copyBtn.classList.add('done');
      copyBtn.innerHTML = TICK_ICON + 'Copied';
      if (copyResetTimer) clearTimeout(copyResetTimer);
      copyResetTimer = setTimeout(function () {
        copyBtn.classList.remove('done');
        copyBtn.innerHTML = COPY_ICON + 'Copy';
      }, 1400);
    });
  }

  /* =====================================================================
     3) MOBILE NAV
     ===================================================================== */
  function initNav() {
    var nav = document.querySelector('.lp-nav');
    var btn = document.querySelector('.lp-nav-toggle');
    var menu = document.getElementById('lp-nav-menu');
    if (!nav || !btn || !menu) return;

    function setOpen(open) {
      nav.classList.toggle('is-open', open);
      btn.setAttribute('aria-expanded', open ? 'true' : 'false');
      btn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    }

    btn.addEventListener('click', function () {
      setOpen(!nav.classList.contains('is-open'));
    });

    menu.querySelectorAll('a[href^="#"]').forEach(function (link) {
      link.addEventListener('click', function () { setOpen(false); });
    });

    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') setOpen(false);
    });

    window.addEventListener('resize', function () {
      if (window.innerWidth > 860) setOpen(false);
    });
  }

  /* ---- boot ---- */
  function boot() { initNav(); initDemo(); initFormats(); }
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
