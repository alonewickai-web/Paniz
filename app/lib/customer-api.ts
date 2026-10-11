import { apiBaseUrl } from "./catalog";

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
  unit: string | null;
  deliveryDetails: string | null;
  addressLine: string;
  postalCode: string;
  isDefault: boolean;
};

export type CustomerProfile = {
  id: string;
  phone: string;
  fullName: string | null;
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
  items: { name: string; color: string; size: string; quantity: number }[];
};

export class CustomerApiError extends Error {
  constructor(message: string, readonly status: number, readonly code?: string) {
    super(message);
  }
}

export async function customerApi<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body && !headers.has("Content-Type")) headers.set("Content-Type", "application/json");
  let response: Response;
  try {
    response = await fetch(`${apiBaseUrl()}${path}`, {
      ...init,
      headers,
      credentials: "include",
      cache: "no-store",
    });
  } catch {
    throw new CustomerApiError("ارتباط با API برقرار نشد. Start.bat را اجرا کن و مطمئن شو سرویس روی پورت ۴۰۰۰ فعال است.", 0, "API_UNREACHABLE");
  }
  const payload = await response.json().catch(() => null) as {
    data?: T;
    message?: string | string[];
    code?: string;
    error?: { message?: string | string[]; code?: string };
  } | null;
  if (!response.ok) {
    const rawMessage = payload?.error?.message ?? payload?.message;
    const message = typeof rawMessage === "string"
      ? rawMessage
      : Array.isArray(rawMessage)
        ? rawMessage.join("، ")
        : "در ارتباط با حساب کاربری مشکلی پیش آمد.";
    throw new CustomerApiError(message, response.status, payload?.error?.code ?? payload?.code);
  }
  return payload?.data as T;
}
