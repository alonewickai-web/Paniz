"use client";

import { useEffect, useRef, useState } from "react";
import { Bell, Download, Share, Sparkles, Smartphone, X } from "lucide-react";
import { requestMarketingPush } from "../lib/customer-push";

const notificationChoiceKey = "panizstyle:marketing-push-prompt:v1";
const installChoiceKey = "panizstyle:pwa-install-prompt:v1";

type PromptStep = "notifications" | "install" | null;
type InstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed"; platform: string }>;
};

export function MarketingPushPrompt() {
  const [step, setStep] = useState<PromptStep>(null);
  const [busy, setBusy] = useState(false);
  const [permissionBlocked, setPermissionBlocked] = useState(false);
  const [iosNeedsInstall, setIosNeedsInstall] = useState(false);
  const [installHelp, setInstallHelp] = useState(false);
  const [installPromptAvailable, setInstallPromptAvailable] = useState(false);
  const [installInstructions, setInstallInstructions] = useState("");
  const [flowResolved, setFlowResolved] = useState(false);
  const [error, setError] = useState("");
  const installPrompt = useRef<InstallPromptEvent | null>(null);

  useEffect(() => {
    const isInstalled = window.matchMedia("(display-mode: standalone)").matches
      || (navigator as Navigator & { standalone?: boolean }).standalone === true;
    const isIos = /iPhone|iPad|iPod/i.test(navigator.userAgent);
    setIosNeedsInstall(isIos && !isInstalled);
    if (isInstalled) {
      window.localStorage.setItem(installChoiceKey, "installed");
    }

    const onBeforeInstallPrompt = (event: Event) => {
      event.preventDefault();
      installPrompt.current = event as InstallPromptEvent;
      setInstallPromptAvailable(true);
    };
    const onAppInstalled = () => {
      window.localStorage.setItem(installChoiceKey, "installed");
      setStep(null);
      setFlowResolved(true);
    };
    window.addEventListener("beforeinstallprompt", onBeforeInstallPrompt);
    window.addEventListener("appinstalled", onAppInstalled);

    const userAgent = navigator.userAgent;
    setInstallInstructions(/iPhone|iPad|iPod/i.test(userAgent)
      ? "در Safari، دکمهٔ اشتراک‌گذاری را بزن و «افزودن به صفحهٔ اصلی» را انتخاب کن."
      : /Android/i.test(userAgent)
        ? "از منوی مرورگر، «نصب برنامه» یا «افزودن به صفحهٔ اصلی» را انتخاب کن."
        : "از منوی مرورگر یا آیکن نصب کنار نوار نشانی، «نصب برنامه» را انتخاب کن.");

    const hasNotificationSupport = "Notification" in window && "serviceWorker" in navigator && "PushManager" in window;
    const previousNotificationChoice = window.localStorage.getItem(notificationChoiceKey);
    const notificationDone = previousNotificationChoice === "dismissed"
      || previousNotificationChoice === "enabled"
      || (hasNotificationSupport && Notification.permission !== "default");
    const installDismissed = window.localStorage.getItem(installChoiceKey) === "dismissed";
    const nextStep: PromptStep = hasNotificationSupport && !notificationDone
      ? "notifications"
      : isInstalled || installDismissed ? null : "install";
    const timer = window.setTimeout(() => {
      setStep(nextStep);
      if (!nextStep) setFlowResolved(true);
    }, 900);

    return () => {
      window.clearTimeout(timer);
      window.removeEventListener("beforeinstallprompt", onBeforeInstallPrompt);
      window.removeEventListener("appinstalled", onAppInstalled);
    };
  }, []);

  useEffect(() => {
    if (flowResolved) window.dispatchEvent(new Event("paniz:entry-prompts-finished"));
  }, [flowResolved]);

  function continueToInstall() {
    window.localStorage.setItem(notificationChoiceKey, "dismissed");
    setError("");
    const installDismissed = window.localStorage.getItem(installChoiceKey) === "dismissed";
    setStep(installDismissed ? null : "install");
    if (installDismissed) setFlowResolved(true);
  }

  async function enableNotifications() {
    if (iosNeedsInstall) {
      setStep("install");
      return;
    }

    setBusy(true);
    setError("");
    try {
      await requestMarketingPush();
      window.localStorage.setItem(notificationChoiceKey, "enabled");
      const installDismissed = window.localStorage.getItem(installChoiceKey) === "dismissed";
      setStep(installDismissed ? null : "install");
      if (installDismissed) setFlowResolved(true);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "فعال‌سازی اعلان انجام نشد.");
      if ("Notification" in window && Notification.permission === "denied") setPermissionBlocked(true);
    } finally {
      setBusy(false);
    }
  }

  async function installApp() {
    const promptEvent = installPrompt.current;
    if (!promptEvent) {
      setInstallHelp(true);
      return;
    }

    setBusy(true);
    try {
      await promptEvent.prompt();
      const choice = await promptEvent.userChoice;
      const result = choice.outcome === "accepted" ? "installed" : "dismissed";
      window.localStorage.setItem(installChoiceKey, result);
      installPrompt.current = null;
      setInstallPromptAvailable(false);
      setStep(null);
      setFlowResolved(true);
    } catch {
      setInstallHelp(true);
    } finally {
      setBusy(false);
    }
  }

  function dismissInstall() {
    window.localStorage.setItem(installChoiceKey, "dismissed");
    setStep(null);
    setFlowResolved(true);
  }

  if (!step) return null;
  const showingNotifications = step === "notifications";

  return <aside className="marketing-push-prompt" aria-labelledby="marketing-push-title" aria-describedby="marketing-push-copy">
    <button className="marketing-push-close" type="button" onClick={showingNotifications ? continueToInstall : dismissInstall} aria-label={showingNotifications ? "رفتن به پیشنهاد نصب برنامه" : "بستن پیشنهاد نصب برنامه"}><X size={18} /></button>
    <span className="marketing-push-icon" aria-hidden="true">{showingNotifications ? <Bell size={21} /> : <Smartphone size={21} />}</span>
    <div className="marketing-push-content">
      {showingNotifications ? <>
        <h2 id="marketing-push-title"><Sparkles size={16} aria-hidden="true" /> تخفیف‌ها و محصولات تازه</h2>
        <p id="marketing-push-copy">{iosNeedsInstall
          ? "برای فعال‌کردن اعلان تخفیف‌ها و محصولات تازه، اول پانیذ را به صفحهٔ اصلی اضافه کن."
          : "برای باخبرشدن از تخفیف‌ها و محصولات تازهٔ پانیذ، اعلان‌ها را فعال کن. هر زمان بخواهی می‌توانی آن را از تنظیمات مرورگر خاموش کنی."}</p>
        {error && <p className="marketing-push-error" role="alert">{error}</p>}
        <div className="marketing-push-actions">
          <button className="button-primary" type="button" onClick={() => void enableNotifications()} disabled={busy || (permissionBlocked && !iosNeedsInstall)}>
            {iosNeedsInstall ? "ادامه به نصب برنامه" : busy ? "در حال فعال‌سازی…" : permissionBlocked ? "اعلان در مرورگر مسدود است" : "فعال‌کردن اعلان‌ها"}
          </button>
          <button className="marketing-push-later" type="button" onClick={continueToInstall} disabled={busy}>بعداً</button>
        </div>
      </> : <>
        <h2 id="marketing-push-title"><Download size={16} aria-hidden="true" /> نصب برنامهٔ پانیذ</h2>
        <p id="marketing-push-copy">با افزودن فروشگاه به صفحهٔ اصلی، راحت‌تر به محصولات و سبد خریدت دسترسی داشته باش.</p>
        {installHelp && <div className="pwa-install-steps" role="status"><Share size={17} aria-hidden="true" /><span>{installInstructions}</span></div>}
        <div className="marketing-push-actions">
          {installHelp
            ? <button className="button-primary" type="button" onClick={dismissInstall}>متوجه شدم</button>
            : <button className="button-primary" type="button" onClick={() => void installApp()} disabled={busy}>{busy ? "در حال آماده‌سازی…" : installPromptAvailable ? "نصب برنامه" : "راهنمای نصب برنامه"}</button>}
          <button className="marketing-push-later" type="button" onClick={dismissInstall} disabled={busy}>فعلاً نه</button>
        </div>
      </>}
    </div>
  </aside>;
}
