const DEFAULT_SITE_URL = "https://panizstyle.ir";

export function siteUrl(path = "/") {
  const configuredUrl = process.env.NEXT_PUBLIC_SITE_URL || DEFAULT_SITE_URL;
  const baseUrl = configuredUrl.endsWith("/") ? configuredUrl : `${configuredUrl}/`;
  return new URL(path, baseUrl).toString();
}
