import { customerApi } from "./customer-api";

type PushOptions = { title: string; body: string; url?: string };

export async function requestMarketingPush(): Promise<void> {
  if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) {
    throw new Error("این مرورگر اعلان پس‌زمینه را پشتیبانی نمی‌کند.");
  }
  const permission = Notification.permission === "default" ? await Notification.requestPermission() : Notification.permission;
  if (permission !== "granted") throw new Error("اجازهٔ اعلان داده نشد. اگر مجوز را رد کرده‌ای، آن را از تنظیمات مرورگر فعال کن.");

  const { publicKey } = await customerApi<{ publicKey: string | null }>("/public/push/public-key");
  if (!publicKey) throw new Error("اعلان مرورگر هنوز روی سرور فروشگاه تنظیم نشده است.");
  const registration = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
  const current = await registration.pushManager.getSubscription();
  const subscription = current ?? await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: decodeVapidKey(publicKey) });
  const json = subscription.toJSON();
  if (!json.endpoint || !json.keys?.p256dh || !json.keys.auth) throw new Error("ثبت اعلان در مرورگر کامل نشد.");
  await customerApi("/public/push/marketing-subscriptions", { method: "POST", body: JSON.stringify({ endpoint: json.endpoint, keys: json.keys }) });
}

export async function requestStorePush(): Promise<void> {
  if (!("serviceWorker" in navigator) || !("PushManager" in window) || !("Notification" in window)) {
    throw new Error("این مرورگر اعلان پس‌زمینه را پشتیبانی نمی‌کند.");
  }
  const { publicKey } = await customerApi<{ publicKey: string | null }>("/customer/push/public-key");
  if (!publicKey) throw new Error("اعلان مرورگر هنوز روی سرور فروشگاه تنظیم نشده است.");
  const permission = Notification.permission === "default" ? await Notification.requestPermission() : Notification.permission;
  if (permission !== "granted") throw new Error("اجازهٔ اعلان داده نشد. می‌توانی از تنظیمات مرورگر فعالش کنی.");
  const registration = await navigator.serviceWorker.register("/sw.js", { scope: "/" });
  const current = await registration.pushManager.getSubscription();
  const subscription = current ?? await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: decodeVapidKey(publicKey) });
  const json = subscription.toJSON();
  if (!json.endpoint || !json.keys?.p256dh || !json.keys.auth) throw new Error("ثبت اعلان در مرورگر کامل نشد.");
  await customerApi("/customer/push/subscriptions", { method: "POST", body: JSON.stringify({ endpoint: json.endpoint, keys: json.keys }) });
}

export async function showStoreNotification(options: PushOptions) {
  if (!("Notification" in window) || Notification.permission !== "granted") return;
  const registration = await navigator.serviceWorker.getRegistration("/");
  if (registration) await registration.showNotification(options.title, { body: options.body, icon: "/icon-192.png", badge: "/icon-192.png", data: { url: options.url ?? "/account" } });
}

function decodeVapidKey(value: string): ArrayBuffer {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/").padEnd(Math.ceil(value.length / 4) * 4, "=");
  const raw = atob(padded);
  const bytes = new Uint8Array(raw.length);
  for (let index = 0; index < raw.length; index++) bytes[index] = raw.charCodeAt(index);
  return bytes.buffer;
}
