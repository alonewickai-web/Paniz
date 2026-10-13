import { ForbiddenException } from "@nestjs/common";

export const ADMIN_PERMISSION_GROUPS = [
  {
    key: "products",
    title: "محصولات",
    permissions: [
      ["products.view", "مشاهدهٔ محصولات"],
      ["products.create", "افزودن محصول"],
      ["products.edit", "ویرایش محصول"],
      ["products.archive", "بایگانی محصول"],
      ["products.change_price", "تغییر قیمت"],
      ["products.change_stock", "تغییر موجودی"],
      ["products.publish", "انتشار محصول"],
    ],
  },
  {
    key: "orders",
    title: "سفارش‌ها",
    permissions: [
      ["orders.view", "مشاهدهٔ سفارش‌ها"],
      ["orders.status", "تغییر وضعیت سفارش"],
      ["orders.edit", "ویرایش سفارش"],
      ["orders.cancel", "لغو سفارش"],
      ["orders.refund", "بازپرداخت سفارش"],
      ["orders.view_contact", "مشاهدهٔ تماس و نشانی مشتری"],
    ],
  },
  {
    key: "customers",
    title: "مشتریان",
    permissions: [
      ["customers.view", "مشاهدهٔ مشتریان"],
      ["customers.edit", "ویرایش مشتری"],
      ["customers.message", "ارسال پیام"],
      ["customers.export", "خروجی اطلاعات مشتریان"],
    ],
  },
  {
    key: "marketing",
    title: "بازاریابی",
    permissions: [
      ["marketing.sms.view", "مشاهدهٔ پیامک‌ها"],
      ["marketing.sms.send", "ارسال پیامک"],
      ["marketing.sms.templates", "مدیریت قالب‌های پیامک"],
      ["marketing.rubika.view", "مشاهدهٔ روبیکا"],
      ["marketing.rubika.publish", "انتشار در روبیکا"],
      ["marketing.campaign.manage", "مدیریت کمپین‌ها"],
      ["loyalty.manage", "مدیریت باشگاه مشتریان"],
    ],
  },
  {
    key: "reports",
    title: "گزارش‌ها",
    permissions: [
      ["reports.view", "مشاهدهٔ آمار"],
      ["reports.financial", "مشاهدهٔ اطلاعات مالی"],
      ["reports.export", "دریافت خروجی گزارش‌ها"],
    ],
  },
  {
    key: "management",
    title: "مدیریت و تنظیمات",
    permissions: [
      ["staff.activity", "مشاهدهٔ فعالیت کارکنان"],
      ["staff.manage", "مدیریت کارکنان و دسترسی‌ها"],
      ["store.content", "مدیریت ظاهر و محتوای سایت"],
      ["system.monitor", "مشاهدهٔ وضعیت سرور"],
      ["system.backup", "مدیریت نسخه‌های پشتیبان"],
      ["system.release", "انتشار نسخهٔ برنامه"],
      ["security.manage", "مدیریت تنظیمات امنیتی"],
    ],
  },
] as const;

export const ALL_ADMIN_PERMISSION_KEYS = ADMIN_PERMISSION_GROUPS.flatMap((group) =>
  group.permissions.map(([key]) => key),
);

export type AdminPermissionKey = (typeof ALL_ADMIN_PERMISSION_KEYS)[number];

export type PermissionAwareAdmin = {
  role: string;
  permissions?: string[];
};

export function hasAdminPermission(admin: PermissionAwareAdmin, permission: string): boolean {
  if (admin.role === "owner" || admin.role === "admin") return true;
  return admin.permissions?.includes(permission) ?? false;
}

export function requireAdminPermission(admin: PermissionAwareAdmin, permission: string): void {
  if (!hasAdminPermission(admin, permission)) {
    throw new ForbiddenException({
      code: "ADMIN_PERMISSION_REQUIRED",
      message: "برای این عملیات دسترسی لازم را ندارید.",
      permission,
    });
  }
}

export function serializePermissionGroups() {
  return ADMIN_PERMISSION_GROUPS.map((group) => ({
    key: group.key,
    title: group.title,
    permissions: group.permissions.map(([key, title]) => ({ key, title })),
  }));
}
