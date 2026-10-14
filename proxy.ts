import { NextRequest, NextResponse } from "next/server";
import { apiBaseUrl } from "./app/lib/catalog";

export async function proxy(request: NextRequest) {
  const slug = request.nextUrl.pathname.split("/")[2];
  if (!slug) return NextResponse.next();
  try {
    const response = await fetch(`${apiBaseUrl()}/products/redirects/${encodeURIComponent(decodeURIComponent(slug))}`, {
      cache: "no-store",
      signal: AbortSignal.timeout(1800),
    });
    if (response.ok) {
      const payload = await response.json() as { data?: { redirectTo?: string } | null };
      const target = payload.data?.redirectTo;
      if (target && /^\/products\/[^/?#]+$/u.test(target) && target !== request.nextUrl.pathname) {
        return NextResponse.redirect(new URL(target, request.url), 301);
      }
    }
  } catch {
    // The product page retains its permanent-redirect fallback if this lookup is unavailable.
  }
  return NextResponse.next();
}

export const config = { matcher: "/products/:slug" };
