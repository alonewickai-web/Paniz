export type CustomerAddress = {
  id: string;
  title: string | null;
  recipientName: string;
  recipientPhone: string;
  province: string;
  city: string;
  street: string | null;
  alley: string | null;
  plaqueNumber: string | null;
  floor: string | null;
  unit: string | null;
  backupPhone: string | null;
  latitude: number | null;
  longitude: number | null;
  deliveryDetails: string | null;
  addressLine: string;
  postalCode: string;
  isDefault: boolean;
};

export type CustomerProfile = {
  id: string;
  phone: string;
  fullName: string | null;
  birthDateJalali: string | null;
  email: string | null;
  phoneVerifiedAt: string | null;
  marketingOptIn: boolean;
  rubikaMarketingOptIn: boolean;
  rubikaLinked: boolean;
  addresses: CustomerAddress[];
};

export type CustomerOrder = {
  orderNumber: string;
  status: string;
  paymentStatus: string;
  totalToman: number;
  placedAt: string;
  reservationExpiresAt: string | null;
  subtotalToman: number;
  discountToman: number;
  shippingToman: number;
  items: { name: string; color: string; size: string; quantity: number; unitPriceToman: number; lineTotalToman: number }[];
  timeline: { status: string; note: string | null; at: string }[];
  trackingCode: string | null;
  paymentConfigured: boolean;
};

export class CustomerApiError extends Error {
  constructor(message: string, readonly status: number, readonly code?: string, readonly retryAfterSeconds?: number) {
    super(message);
  }
}

export async function customerApi<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body && !(init.body instanceof FormData) && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
  let response: Response;
  try {
    response = await fetch(`/api/v1${path}`, {
      ...init,
      headers,
      credentials: "include",
      cache: "no-store",
    });
  } catch {
    throw new CustomerApiError("ارتباط با سرور برقرار نشد. اتصال اینترنت را بررسی کن و دوباره تلاش کن.", 0, "API_UNREACHABLE");
  }
  const payload = await response.json().catch(() => null) as {
    data?: T;
    message?: string | string[];
    code?: string;
    error?: { message?: string | string[]; code?: string };
    retryAfterSeconds?: number;
  } | null;
  if (!response.ok) {
    const rawMessage = payload?.error?.message ?? payload?.message;
    const message = typeof rawMessage === "string"
      ? rawMessage
      : Array.isArray(rawMessage)
        ? rawMessage.join("، ")
        : "در ارتباط با حساب کاربری مشکلی پیش آمد.";
    throw new CustomerApiError(message, response.status, payload?.error?.code ?? payload?.code, payload?.retryAfterSeconds);
  }
  return payload?.data as T;
}
import { apiBaseUrl } from "./catalog";


export function customerAssetUrl(path: string | null | undefined): string | null {
  if (!path) return null;
  if (/^https?:\/\//i.test(path)) return path;
  const api = new URL(apiBaseUrl());
  return new URL(path, `${api.origin}/`).toString();
}
