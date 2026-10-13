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
