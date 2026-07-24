(function() {
  // Don't show if already installed as PWA
  if (window.matchMedia('(display-mode: standalone)').matches) return;
  // Don't show if already dismissed
  if (localStorage.getItem('pwa-banner-dismissed')) return;

  var isIOS = /iphone|ipad|ipod/i.test(navigator.userAgent);
  var isAndroid = /android/i.test(navigator.userAgent);
  if (!isIOS && !isAndroid) return;

  var isEn = document.body.classList.contains('en');

  // Detect language dynamically (body class may not be set yet)
  function getLang() {
    return document.body.classList.contains('en') ? 'en' : 'es';
  }

  var style = document.createElement('style');
  style.textContent = `
    #pwa-banner {
      position: fixed;
      bottom: 0; left: 0; right: 0;
      background: #1A1A18;
      color: #fff;
      padding: 14px 16px;
      display: flex;
      align-items: center;
      gap: 12px;
      z-index: 9999;
      box-shadow: 0 -2px 16px rgba(0,0,0,0.25);
      font-family: 'DM Sans', system-ui, sans-serif;
      animation: slideUp 0.3s ease;
    }
    @keyframes slideUp {
      from { transform: translateY(100%); }
      to   { transform: translateY(0); }
    }
    #pwa-banner-icon {
      font-size: 28px;
      flex-shrink: 0;
    }
    #pwa-banner-text {
      flex: 1;
      font-size: 13px;
      line-height: 1.45;
    }
    #pwa-banner-text strong {
      display: block;
      font-size: 14px;
      margin-bottom: 2px;
    }
    #pwa-banner-btn {
      background: #C94F2B;
      color: #fff;
      border: none;
      border-radius: 8px;
      padding: 8px 14px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      white-space: nowrap;
      font-family: inherit;
      flex-shrink: 0;
    }
    #pwa-banner-close {
      background: none;
      border: none;
      color: rgba(255,255,255,0.5);
      font-size: 20px;
      cursor: pointer;
      padding: 0 4px;
      line-height: 1;
      flex-shrink: 0;
    }
    #pwa-install-guide {
      position: fixed;
      bottom: 0; left: 0; right: 0;
      background: #fff;
      border-radius: 18px 18px 0 0;
      padding: 24px 20px 32px;
      z-index: 10000;
      box-shadow: 0 -4px 32px rgba(0,0,0,0.18);
      font-family: 'DM Sans', system-ui, sans-serif;
      animation: slideUp 0.3s ease;
    }
    #pwa-install-guide h3 {
      font-size: 17px;
      font-weight: 700;
      margin-bottom: 16px;
      color: #1A1A18;
    }
    .pwa-step {
      display: flex;
      align-items: flex-start;
      gap: 12px;
      margin-bottom: 14px;
      font-size: 14px;
      color: #1A1A18;
      line-height: 1.5;
    }
    .pwa-step-num {
      background: #C94F2B;
      color: #fff;
      border-radius: 50%;
      width: 24px; height: 24px;
      display: flex; align-items: center; justify-content: center;
      font-size: 12px; font-weight: 700;
      flex-shrink: 0;
    }
    #pwa-guide-close {
      display: block;
      width: 100%;
      margin-top: 20px;
      padding: 12px;
      background: #1A1A18;
      color: #fff;
      border: none;
      border-radius: 10px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      font-family: inherit;
    }
    #pwa-overlay {
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.4);
      z-index: 9999;
    }
  `;
  document.head.appendChild(style);

  // Build banner
  var banner = document.createElement('div');
  banner.id = 'pwa-banner';

  var lang = getLang();
  var textES = isIOS
    ? '<strong>Úsanos como app 📲</strong>Instala AmigosNearMe en tu pantalla de inicio'
    : '<strong>Úsanos como app 📲</strong>Instala AmigosNearMe en tu teléfono';
  var textEN = isIOS
    ? '<strong>Use us as an app 📲</strong>Add AmigosNearMe to your home screen'
    : '<strong>Use us as an app 📲</strong>Install AmigosNearMe on your phone';
  var btnES = 'Instalar';
  var btnEN = 'Install';

  banner.innerHTML =
    '<div id="pwa-banner-text">' + (lang === 'en' ? textEN : textES) + '</div>' +
    '<button id="pwa-banner-btn">' + (lang === 'en' ? btnEN : btnES) + '</button>' +
    '<button id="pwa-banner-close" aria-label="Close">✕</button>';

  document.body.appendChild(banner);

  // Update text when language changes
  var observer = new MutationObserver(function() {
    var l = getLang();
    document.getElementById('pwa-banner-text').innerHTML = l === 'en' ? textEN : textES;
    document.getElementById('pwa-banner-btn').textContent = l === 'en' ? btnEN : btnES;
  });
  observer.observe(document.body, { attributes: true, attributeFilter: ['class'] });

  // Close banner
  document.getElementById('pwa-banner-close').addEventListener('click', function() {
    localStorage.setItem('pwa-banner-dismissed', '1');
    banner.remove();
  });

  // Show install guide
  document.getElementById('pwa-banner-btn').addEventListener('click', function() {
    var l = getLang();
    banner.style.display = 'none';

    var overlay = document.createElement('div');
    overlay.id = 'pwa-overlay';
    document.body.appendChild(overlay);

    var guide = document.createElement('div');
    guide.id = 'pwa-install-guide';

    if (isIOS) {
      guide.innerHTML = l === 'en' ? `
        <h3>Add to Home Screen</h3>
        <div class="pwa-step"><div class="pwa-step-num">1</div><div>Tap the <strong>Share button</strong> <svg width="16" height="18" viewBox="0 0 16 18" fill="none" xmlns="http://www.w3.org/2000/svg" style="vertical-align:middle;display:inline-block"><rect x="1" y="6" width="14" height="11" rx="2" stroke="#1A1A18" stroke-width="1.5" fill="none"/><line x1="8" y1="1" x2="8" y2="12" stroke="#1A1A18" stroke-width="1.5" stroke-linecap="round"/><polyline points="4.5,4.5 8,1 11.5,4.5" stroke="#1A1A18" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg> at the bottom of Safari</div></div>
        <div class="pwa-step"><div class="pwa-step-num">2</div><div>Scroll down and tap <strong>"Add to Home Screen"</strong></div></div>
        <div class="pwa-step"><div class="pwa-step-num">3</div><div>Tap <strong>"Add"</strong> — done! Open it from your home screen like an app.</div></div>
        <button id="pwa-guide-close">Got it</button>
      ` : `
        <h3>Agregar a pantalla de inicio</h3>
        <div class="pwa-step"><div class="pwa-step-num">1</div><div>Toca el <strong>botón Compartir</strong> <svg width="16" height="18" viewBox="0 0 16 18" fill="none" xmlns="http://www.w3.org/2000/svg" style="vertical-align:middle;display:inline-block"><rect x="1" y="6" width="14" height="11" rx="2" stroke="#1A1A18" stroke-width="1.5" fill="none"/><line x1="8" y1="1" x2="8" y2="12" stroke="#1A1A18" stroke-width="1.5" stroke-linecap="round"/><polyline points="4.5,4.5 8,1 11.5,4.5" stroke="#1A1A18" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg> en la parte inferior de Safari</div></div>
        <div class="pwa-step"><div class="pwa-step-num">2</div><div>Desplázate y toca <strong>"Agregar a pantalla de inicio"</strong></div></div>
        <div class="pwa-step"><div class="pwa-step-num">3</div><div>Toca <strong>"Agregar"</strong> — ¡listo! Ábrelo desde tu pantalla de inicio como una app.</div></div>
        <button id="pwa-guide-close">Entendido</button>
      `;
    } else {
      guide.innerHTML = l === 'en' ? `
        <h3>Install the app</h3>
        <div class="pwa-step"><div class="pwa-step-num">1</div><div>Tap the <strong>menu (⋮)</strong> in the top-right corner of Chrome</div></div>
        <div class="pwa-step"><div class="pwa-step-num">2</div><div>Tap <strong>"Add to Home screen"</strong> or <strong>"Install app"</strong></div></div>
        <div class="pwa-step"><div class="pwa-step-num">3</div><div>Tap <strong>"Install"</strong> — done! Open it from your home screen.</div></div>
        <button id="pwa-guide-close">Got it</button>
      ` : `
        <h3>Instalar la app</h3>
        <div class="pwa-step"><div class="pwa-step-num">1</div><div>Toca el <strong>menú (⋮)</strong> en la esquina superior derecha de Chrome</div></div>
        <div class="pwa-step"><div class="pwa-step-num">2</div><div>Toca <strong>"Agregar a pantalla de inicio"</strong> o <strong>"Instalar app"</strong></div></div>
        <div class="pwa-step"><div class="pwa-step-num">3</div><div>Toca <strong>"Instalar"</strong> — ¡listo! Ábrelo desde tu pantalla de inicio.</div></div>
        <button id="pwa-guide-close">Entendido</button>
      `;
    }

    document.body.appendChild(guide);

    document.getElementById('pwa-guide-close').addEventListener('click', function() {
      guide.remove();
      overlay.remove();
      localStorage.setItem('pwa-banner-dismissed', '1');
      banner.remove();
    });
    overlay.addEventListener('click', function() {
      guide.remove();
      overlay.remove();
      banner.style.display = '';
    });
  });
})();
