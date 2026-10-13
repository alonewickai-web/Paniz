"use client";

import { useEffect } from "react";
import { apiBaseUrl } from "../lib/catalog";

const supportedThemes = new Set([
  "rose", "mint", "peach", "lilac", "coral", "dark", "berry", "ocean",
  "sunset", "forest", "royal", "citrus", "lagoon", "mocha", "orchid", "slate",
]);

type StorefrontConfig = { data?: { theme?: unknown } };

export function StoreThemeSync() {
  useEffect(() => {
    let requestInFlight = false;

    const syncTheme = async () => {
      if (requestInFlight || document.visibilityState !== "visible") return;
      requestInFlight = true;
      const controller = new AbortController();
      const timeout = window.setTimeout(() => controller.abort(), 5_000);

      try {
        const response = await fetch(`${apiBaseUrl()}/storefront/config`, {
          cache: "no-store",
          signal: controller.signal,
        });
        if (!response.ok) return;

        const payload = (await response.json()) as StorefrontConfig;
        const theme = payload.data?.theme;
        if (typeof theme === "string" && supportedThemes.has(theme)) {
          document.documentElement.dataset.theme = theme;
        }
      } catch {
        // Keep the server-rendered theme if the API is temporarily unavailable.
      } finally {
        window.clearTimeout(timeout);
        requestInFlight = false;
      }
    };

    const onVisibilityChange = () => {
      if (document.visibilityState === "visible") void syncTheme();
    };

    window.addEventListener("focus", syncTheme);
    document.addEventListener("visibilitychange", onVisibilityChange);
    return () => {
      window.removeEventListener("focus", syncTheme);
      document.removeEventListener("visibilitychange", onVisibilityChange);
    };
  }, []);

  return null;
}
