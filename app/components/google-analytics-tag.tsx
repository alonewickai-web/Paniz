import Script from "next/script";

const measurementId = process.env.NEXT_PUBLIC_GA4_MEASUREMENT_ID;

export function GoogleAnalyticsTag() {
  if (!measurementId || !/^G-[A-Z0-9]+$/u.test(measurementId)) return null;
  return <>
    <Script src={`https://www.googletagmanager.com/gtag/js?id=${measurementId}`} strategy="afterInteractive" />
    <Script id="paniz-ga4-bootstrap" strategy="beforeInteractive">
      {`window.dataLayer = window.dataLayer || []; window.gtag = window.gtag || function(){window.dataLayer.push(arguments);}; window.gtag('js', new Date()); window.gtag('config', '${measurementId}', {send_page_view: false, allow_google_signals: false, allow_ad_personalization_signals: false});`}
    </Script>
  </>;
}
