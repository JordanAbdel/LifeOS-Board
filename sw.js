/* Life Dashboard — Service Worker v1.0.3
   Network-first strategy: always tries the network, falls back to cache.
   This ensures you always get fresh data from Supabase.
*/

const CACHE = "ld-v1.0.3";

const PRECACHE = [
  "/",
  "/index.html",
  "/icons/icon-192.png",
  "/icons/icon-512.png",
  "https://fonts.googleapis.com/css2?family=Source+Serif+4:ital,opsz,wght@0,8..60,400;0,8..60,500;0,8..60,600;1,8..60,400&family=Geist+Mono:wght@400;500&family=Geist:wght@400;500;600&display=swap",
  "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js",
  "https://unpkg.com/react@18.3.1/umd/react.development.js",
  "https://unpkg.com/react-dom@18.3.1/umd/react-dom.development.js",
  "https://unpkg.com/@babel/standalone@7.29.0/babel.min.js"
];

self.addEventListener("install", e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", e => {
  // Let Supabase API calls always go to network — never cache them
  if (e.request.url.includes("supabase.co")) {
    e.respondWith(fetch(e.request));
    return;
  }

  // Network-first for everything else: try network, fall back to cache
  e.respondWith(
    fetch(e.request)
      .then(res => {
        if (res.ok) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return res;
      })
      .catch(() => caches.match(e.request))
  );
});
