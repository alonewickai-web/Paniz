"use client";

import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";

const visitorStorageKey = "panizstyle.analytics.visitor";

export function SiteVisitTracker() {
  const pathname = usePathname();
  const lastTrackedPath = useRef<string | null>(null);

  useEffect(() => {
    if (!pathname || lastTrackedPath.current === pathname) return;
    lastTrackedPath.current = pathname;

    let visitorId: string;
    try {
      visitorId = window.localStorage.getItem(visitorStorageKey) ?? "";
      if (!/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(visitorId)) {
        visitorId = window.crypto.randomUUID();
        window.localStorage.setItem(visitorStorageKey, visitorId);
      }
    } catch {
      visitorId = window.crypto.randomUUID();
    }

    void fetch("/api/v1/analytics/page-view", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ visitorId, path: pathname }),
      keepalive: true,
    }).catch(() => undefined);
  }, [pathname]);

  return null;
}
