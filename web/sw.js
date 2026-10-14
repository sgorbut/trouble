// Service worker PWA «Trouble»: игра работает офлайн после первого открытия.
//
// Стратегия:
// - навигация (index.html) — сначала сеть, при неудаче кэш: обновления видны сразу,
//   а без интернета открывается сохранённая версия;
// - остальные файлы того же сайта — сначала кэш, параллельно обновление из сети
//   (stale-while-revalidate).
// При первой установке заранее кэшируются ключевые файлы, остальное — по мере загрузки.

const CACHE = 'trouble-v1';
const CORE = [
  './',
  'index.html',
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'icons/Icon-192.png',
  'icons/Icon-512.png',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE).then((cache) => cache.addAll(CORE)).then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  const url = new URL(request.url);
  // Свой сайт и шрифты Google (Flutter подгружает с fonts.gstatic.com Roboto и Noto,
  // в том числе для эмодзи-аватаров) — без них офлайн пропадёт текст.
  const cacheable = url.origin === self.location.origin || url.hostname === 'fonts.gstatic.com';
  if (request.method !== 'GET' || !cacheable) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, copy));
          return response;
        })
        .catch(() => caches.match(request).then((r) => r || caches.match('index.html'))),
    );
    return;
  }

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      const cached = await cache.match(request);
      const network = fetch(request)
        .then((response) => {
          if (response.ok || response.type === 'opaque') cache.put(request, response.clone());
          return response;
        })
        .catch(() => cached);
      return cached || network;
    }),
  );
});
