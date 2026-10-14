export type Ga4Item = {
  item_id: string;
  item_name: string;
  item_category?: string;
  item_variant?: string;
  price?: number;
  quantity?: number;
};

type GtagFunction = (command: string, eventName: string, parameters?: Record<string, unknown>) => void;

declare global {
  interface Window {
    dataLayer?: unknown[];
    gtag?: GtagFunction;
  }
}

export function trackGa4(eventName: string, parameters: Record<string, unknown>) {
  const measurementId = process.env.NEXT_PUBLIC_GA4_MEASUREMENT_ID;
  if (typeof window === "undefined" || !measurementId || !/^G-[A-Z0-9]+$/u.test(measurementId)) return;
  if (!window.gtag) {
    window.dataLayer = window.dataLayer ?? [];
    window.gtag = function () { window.dataLayer?.push(arguments); };
  }
  window.gtag("event", eventName, { ...parameters, send_to: measurementId });
}

export function trackGa4Purchase(
  transactionId: string,
  valueToman: number,
  shippingToman: number,
  items: Ga4Item[],
) {
  const measurementId = process.env.NEXT_PUBLIC_GA4_MEASUREMENT_ID;
  if (typeof window === "undefined" || !measurementId || !/^G-[A-Z0-9]+$/u.test(measurementId) || !transactionId || !Number.isFinite(valueToman) || !items.length) return;
  try {
    const key = `panizstyle.ga4.purchase.${transactionId}`;
    if (window.sessionStorage.getItem(key)) return;
    window.sessionStorage.setItem(key, "1");
  } catch {
    // GA4 also deduplicates web purchase events by transaction_id.
  }
  trackGa4("purchase", {
    transaction_id: transactionId,
    currency: "IRR",
    value: Math.round(Math.max(0, valueToman - shippingToman) * 10),
    shipping: Math.round(shippingToman * 10),
    items,
  });
}
