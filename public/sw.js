self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open("paniz-offline-v1")
      .then((cache) => Promise.all([
        cache.add("/offline.html").catch(() => undefined),
        cache.add("/icon-192.png").catch(() => undefined),
      ]))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => key.startsWith("paniz-offline-") && key !== "paniz-offline-v1").map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET" || event.request.mode !== "navigate") return;
  event.respondWith(
    fetch(event.request).then((response) => {
      if (response.status < 500) return response;
      return caches.match("/offline.html").then((offline) => offline || response);
    }).catch(async () => (await caches.match("/offline.html")) || Response.error()),
  );
});

self.addEventListener("push", (event) => {
  let payload = {};
  try { payload = event.data ? event.data.json() : {}; } catch { payload = { body: event.data?.text() || "" }; }
  const title = payload.title || "خبر تازه از پانیذ";
  event.waitUntil(self.registration.showNotification(title, {
    body: payload.body || "برای دیدن جزئیات وارد فروشگاه شو.",
    icon: "/icon-192.png",
    badge: "/icon-192.png",
    data: { url: payload.url || "/account" },
    dir: "rtl",
    lang: "fa",
  }));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = new URL(event.notification.data?.url || "/account", self.location.origin).href;
  event.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clients) => {
    const existing = clients.find((client) => client.url.startsWith(self.location.origin));
    if (existing) return existing.navigate(target).then(() => existing.focus());
    return self.clients.openWindow(target);
  }));
});
