import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { randomBytes } from "node:crypto";
import { PrismaService } from "../database/prisma.service";
import { AdminNotificationService } from "../admin-notifications/admin-notification.service";
import { CreateCustomerOrderDto } from "../customer/dto/create-customer-order.dto";
import { CartItemDto } from "./dto/cart-item.dto";
import { TrackOrderDto } from "./dto/track-order.dto";

const RESERVATION_MINUTES = 15;

type QuotedLine = {
  variantId: bigint;
  quantity: number;
  sku: string;
  colorName: string;
  sizeLabel: string;
  unitPriceToman: bigint;
  purchaseCostToman: bigint;
  productId: bigint;
  categoryId: bigint | null;
  productName: string;
};

@Injectable()
export class OrdersService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(OrdersService.name);
  private expirationTimer?: NodeJS.Timeout;

  constructor(
    private readonly prisma: PrismaService,
    private readonly notifications: AdminNotificationService,
  ) {}

  onModuleInit(): void {
    this.expirationTimer = setInterval(() => {
      void this.releaseExpiredReservations().catch(() => {
        this.logger.error("Could not release expired inventory reservations.");
      });
    }, 30_000);
    this.expirationTimer.unref();
    void this.releaseExpiredReservations().catch(() => {
      this.logger.error("Could not release expired inventory reservations.");
    });
  }

  onModuleDestroy(): void {
    if (this.expirationTimer) clearInterval(this.expirationTimer);
  }

  async quote(items: CartItemDto[], couponCode?: string) {
    const lines = await this.getQuotedLines(this.prisma, items);
    const subtotalToman = lines.reduce(
      (sum, line) => sum + line.unitPriceToman * BigInt(line.quantity),
      0n,
    );
    const coupon = couponCode?.trim() ? await this.calculateCoupon(this.prisma, couponCode, lines, subtotalToman) : null;
    const discountToman = coupon?.discountToman ?? 0n;
    const shippingMethod = await this.prisma.shippingMethod.findFirst({
      where: { isActive: true }, orderBy: [{ sortOrder: "asc" }, { id: "asc" }],
      select: { id: true, name: true, baseCostToman: true, freeOverToman: true },
    });
    const payableProductsToman = subtotalToman - discountToman;
    const shippingToman = shippingMethod
      ? shippingMethod.freeOverToman !== null && payableProductsToman >= shippingMethod.freeOverToman
        ? 0n : shippingMethod.baseCostToman
      : null;

    return {
      data: {
        items: lines.map((line) => ({
          variantId: line.variantId.toString(),
          productId: line.productId.toString(),
          productName: line.productName,
          sku: line.sku,
          color: line.colorName,
          size: line.sizeLabel,
          quantity: line.quantity,
          unitPriceToman: toSafeNumber(line.unitPriceToman),
          lineTotalToman: toSafeNumber(line.unitPriceToman * BigInt(line.quantity)),
        })),
        subtotalToman: toSafeNumber(subtotalToman),
        discountToman: toSafeNumber(discountToman),
        couponCode: coupon?.code ?? null,
        shippingToman: shippingToman === null ? null : toSafeNumber(shippingToman),
        shippingLabel: shippingMethod?.name ?? null,
        shippingConfigured: shippingMethod !== null,
        totalToman: shippingToman === null ? null : toSafeNumber(payableProductsToman + shippingToman),
        paymentConfigured: Boolean(process.env.PAYMENT_PROVIDER && process.env.PAYMENT_SECRET),
      },
    };
  }

  async createCustomerOrder(customerId: bigint, input: CreateCustomerOrderDto, idempotencyKey: string) {
    if (!idempotencyKey || idempotencyKey.length > 100) {
      throw new BadRequestException({
        code: "IDEMPOTENCY_KEY_REQUIRED",
        message: "شناسهٔ یکتای ثبت سفارش معتبر نیست",
      });
    }

    const existing = await this.findExistingIdempotentOrder(customerId, input, idempotencyKey);
    if (existing) {
      return this.toCreatedOrder(existing);
    }

    const expiresAt = new Date(Date.now() + RESERVATION_MINUTES * 60_000);
    try {
      const order = await this.prisma.$transaction(async (tx) => {
        const address = await tx.customerAddress.findFirst({
          where: { id: BigInt(input.addressId), customerId },
        });
        if (!address) {
          throw new BadRequestException({ code: "CUSTOMER_ADDRESS_REQUIRED", message: "نشانی انتخاب‌شده در حساب کاربری پیدا نشد." });
        }
        if (!address.unit?.trim()) {
          throw new BadRequestException({ code: "CUSTOMER_ADDRESS_UNIT_REQUIRED", message: "برای ثبت سفارش، شمارهٔ واحد نشانی را از حساب کاربری تکمیل کن." });
        }
        const lines = await this.getQuotedLines(tx, input.items);
        const subtotalToman = lines.reduce(
          (sum, line) => sum + line.unitPriceToman * BigInt(line.quantity),
          0n,
        );
        const coupon = input.couponCode?.trim()
          ? await this.calculateCoupon(tx, input.couponCode, lines, subtotalToman, customerId)
          : null;
        const discountToman = coupon?.discountToman ?? 0n;
        const shippingMethod = await tx.shippingMethod.findFirst({
          where: { isActive: true }, orderBy: [{ sortOrder: "asc" }, { id: "asc" }],
          select: { id: true, baseCostToman: true, freeOverToman: true },
        });
        if (!shippingMethod) throw new BadRequestException({ code: "SHIPPING_NOT_CONFIGURED", message: "هزینهٔ ارسال هنوز توسط فروشگاه تنظیم نشده است." });
        const payableProductsToman = subtotalToman - discountToman;
        const shippingToman = shippingMethod.freeOverToman !== null && payableProductsToman >= shippingMethod.freeOverToman
          ? 0n : shippingMethod.baseCostToman;

        for (const line of lines) {
          const reserved = await tx.$executeRaw`
            UPDATE product_variants
            SET reserved_quantity = reserved_quantity + ${line.quantity}, updated_at = CURRENT_TIMESTAMP(3)
            WHERE id = ${line.variantId}
              AND is_active = 1
              AND stock_quantity - reserved_quantity >= ${line.quantity}
          `;
          if (reserved !== 1) {
            throw new ConflictException({
              code: "INSUFFICIENT_STOCK",
              message: `موجودی ${line.productName} تغییر کرده است؛ سبد خرید را دوباره بررسی کن`,
            });
          }
        }

        const orderNumber = makeOrderNumber();
        const order = await tx.order.create({
          data: {
            orderNumber,
            idempotencyKey,
            status: "pending_payment",
            paymentStatus: "unpaid",
            reservationExpiresAt: expiresAt,
            customerId,
            addressId: address.id,
            shippingMethodId: shippingMethod.id,
            subtotalToman,
            discountToman,
            shippingToman,
            totalToman: payableProductsToman + shippingToman,
            couponCodeSnapshot: coupon?.code ?? null,
            recipientNameSnapshot: address.recipientName,
            recipientPhoneSnapshot: address.recipientPhone,
            shippingAddressSnapshot: {
              province: address.province,
              city: address.city,
              street: address.street,
              alley: address.alley,
              plaqueNumber: address.plaqueNumber,
              floor: address.floor,
              unit: address.unit,
              backupPhone: address.backupPhone,
              latitude: address.latitude,
              longitude: address.longitude,
              deliveryDetails: address.deliveryDetails,
              addressLine: address.addressLine,
              postalCode: address.postalCode,
            } satisfies Prisma.InputJsonObject,
            customerNote: input.customerNote?.trim() || null,
            items: {
              create: lines.map((line) => ({
                productId: line.productId,
                variantId: line.variantId,
                productNameSnapshot: line.productName,
                skuSnapshot: line.sku,
                colorNameSnapshot: line.colorName,
                sizeLabelSnapshot: line.sizeLabel,
                unitPriceToman: line.unitPriceToman,
                purchaseCostToman: line.purchaseCostToman,
                quantity: line.quantity,
                lineTotalToman: line.unitPriceToman * BigInt(line.quantity),
              })),
            },
            statusHistory: {
              create: {
                newStatus: "pending_payment",
                note: "سفارش مشتری ثبت شد؛ منتظر تنظیم روش پرداخت است.",
                visibleToCustomer: true,
              },
            },
          },
        });

        if (coupon && discountToman > 0n) {
          await tx.couponRedemption.create({ data: {
            couponId: coupon.id, customerId, orderId: order.id, discountToman,
          } });
        }

        await tx.inventoryMovement.createMany({
          data: lines.map((line) => ({
            variantId: line.variantId,
            movementType: "reservation",
            quantityDelta: 0,
            reservedDelta: line.quantity,
            referenceType: "order",
            referenceId: order.id,
            note: `رزرو موقت سفارش ${order.orderNumber}`,
          })),
        });

        await this.notifications.createForOwners(tx, {
          type: "new_order",
          title: "سفارش جدید ثبت شد",
          body: `سفارش ${order.orderNumber} از ${order.recipientNameSnapshot} ثبت شد.`,
          entityType: "order",
          entityId: order.id,
          dedupeKey: `order:${order.id}`,
        });

        return order;
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });

      return this.toCreatedOrder(order);
    } catch (error) {
      const duplicate = await this.findExistingIdempotentOrder(customerId, input, idempotencyKey);
      if (duplicate) {
        return this.toCreatedOrder(duplicate);
      }
      throw error;
    }
  }

  async trackOrder(input: TrackOrderDto) {
    const order = await this.prisma.order.findFirst({
      where: {
        orderNumber: input.orderNumber.toUpperCase(),
        recipientPhoneSnapshot: normalizePhone(input.phone),
      },
      include: {
        items: {
          select: {
            productNameSnapshot: true,
            colorNameSnapshot: true,
            sizeLabelSnapshot: true,
            quantity: true,
            lineTotalToman: true,
          },
        },
        statusHistory: {
          where: { visibleToCustomer: true },
          orderBy: { createdAt: "asc" },
          select: { newStatus: true, note: true, createdAt: true },
        },
        shipments: { select: { trackingCode: true, status: true, shippedAt: true, deliveredAt: true } },
      },
    });
    if (!order) {
      throw new BadRequestException({
        code: "ORDER_NOT_FOUND",
        message: "سفارشی با این شماره و تلفن پیدا نشد",
      });
    }

    return {
      data: {
        orderNumber: order.orderNumber,
        status: order.status,
        paymentStatus: order.paymentStatus,
        totalToman: toSafeNumber(order.totalToman),
        reservationExpiresAt: order.reservationExpiresAt?.toISOString() ?? null,
        items: order.items.map((item) => ({
          name: item.productNameSnapshot,
          color: item.colorNameSnapshot,
          size: item.sizeLabelSnapshot,
          quantity: item.quantity,
          lineTotalToman: toSafeNumber(item.lineTotalToman),
        })),
        timeline: order.statusHistory.map((entry) => ({
          status: entry.newStatus,
          note: entry.note,
          at: entry.createdAt.toISOString(),
        })),
        shipments: order.shipments.map((shipment) => ({
          trackingCode: shipment.trackingCode,
          status: shipment.status,
          shippedAt: shipment.shippedAt?.toISOString() ?? null,
          deliveredAt: shipment.deliveredAt?.toISOString() ?? null,
        })),
        paymentConfigured: Boolean(process.env.PAYMENT_PROVIDER && process.env.PAYMENT_SECRET),
      },
    };
  }

  private async getQuotedLines(
    db: PrismaService | Prisma.TransactionClient,
    inputItems: CartItemDto[],
  ): Promise<QuotedLine[]> {
    const requested = new Map<bigint, number>();
    for (const item of inputItems) {
      const id = BigInt(item.variantId);
      const quantity = (requested.get(id) ?? 0) + item.quantity;
      if (quantity > 10) {
        throw new BadRequestException({ code: "QUANTITY_LIMIT", message: "حداکثر تعداد هر تنوع ۱۰ عدد است" });
      }
      requested.set(id, quantity);
    }

    const variants = await db.productVariant.findMany({
      where: {
        id: { in: [...requested.keys()] },
        isActive: true,
          product: {
            is: {
              status: "published",
            deletedAt: null,
            publishedAt: { lte: new Date() },
            },
          },
        },
        include: { product: { select: { id: true, name: true, categoryId: true, purchaseCostToman: true } } },
    });

    if (variants.length !== requested.size) {
      throw new ConflictException({
        code: "CART_ITEM_UNAVAILABLE",
        message: "یکی از انتخاب‌های سبد دیگر قابل خرید نیست؛ سبد را تازه‌سازی کن",
      });
    }

    return variants.map((variant) => {
      const quantity = requested.get(variant.id)!;
      const available = variant.stockQuantity - variant.reservedQuantity;
      if (available < quantity) {
        throw new ConflictException({
          code: "INSUFFICIENT_STOCK",
          message: `موجودی ${variant.product.name} برای تعداد انتخاب‌شده کافی نیست`,
        });
      }
      return {
        variantId: variant.id,
        quantity,
        sku: variant.sku,
        colorName: variant.colorName,
        sizeLabel: variant.sizeLabel,
        unitPriceToman: variant.priceToman,
        productId: variant.product.id,
        categoryId: variant.product.categoryId,
        productName: variant.product.name,
        purchaseCostToman: variant.product.purchaseCostToman,
      };
    });
  }

  private async calculateCoupon(
    db: PrismaService | Prisma.TransactionClient,
    rawCode: string,
    lines: QuotedLine[],
    subtotalToman: bigint,
    customerId?: bigint,
  ) {
    const code = rawCode.trim().toUpperCase();
    if (!/^[A-Z0-9_-]{3,64}$/.test(code)) throw new BadRequestException({ code: "COUPON_INVALID", message: "کد تخفیف معتبر نیست." });
    const coupon = await db.coupon.findUnique({ where: { code }, include: { products: true, categories: true } });
    const now = new Date();
    if (!coupon || !coupon.isActive || (coupon.startsAt && coupon.startsAt > now) || (coupon.endsAt && coupon.endsAt <= now)) {
      throw new BadRequestException({ code: "COUPON_UNAVAILABLE", message: "کد تخفیف معتبر یا فعال نیست." });
    }
    const discountValue = Number(coupon.discountValue);
    if (!Number.isFinite(discountValue)
      || discountValue <= 0
      || (coupon.discountType === "percent" && discountValue > 100)
      || (coupon.discountType === "fixed" && !Number.isSafeInteger(discountValue))
      || (coupon.discountType !== "percent" && coupon.discountType !== "fixed")) {
      throw new BadRequestException({ code: "COUPON_UNAVAILABLE", message: "تنظیمات این کد تخفیف معتبر نیست." });
    }
    if (subtotalToman < coupon.minOrderToman) throw new BadRequestException({ code: "COUPON_MINIMUM_NOT_MET", message: "مبلغ سبد خرید به حداقل لازم برای این کد نمی‌رسد." });
    const productIds = new Set(coupon.products.map((item) => item.productId.toString()));
    const categoryIds = new Set(coupon.categories.map((item) => item.categoryId.toString()));
    const hasScope = productIds.size > 0 || categoryIds.size > 0;
    const eligibleLines = hasScope
      ? lines.filter((line) => productIds.has(line.productId.toString()) || (line.categoryId !== null && categoryIds.has(line.categoryId.toString())))
      : lines;
    if (!eligibleLines.length) throw new BadRequestException({ code: "COUPON_PRODUCTS_NOT_ELIGIBLE", message: "این کد برای محصولات سبد خرید فعال نیست." });
    const eligibleSubtotal = eligibleLines.reduce((sum, line) => sum + line.unitPriceToman * BigInt(line.quantity), 0n);
    const redemptionCount = await db.couponRedemption.count({ where: { couponId: coupon.id } });
    if (coupon.usageLimit !== null && redemptionCount >= coupon.usageLimit) throw new BadRequestException({ code: "COUPON_USAGE_LIMIT_REACHED", message: "ظرفیت استفاده از این کد تکمیل شده است." });
    if (customerId) {
      if (coupon.perCustomerLimit !== null) {
        const customerUses = await db.couponRedemption.count({ where: { couponId: coupon.id, customerId } });
        if (customerUses >= coupon.perCustomerLimit) throw new BadRequestException({ code: "COUPON_CUSTOMER_LIMIT_REACHED", message: "سقف استفادهٔ شما از این کد تکمیل شده است." });
      }
      if (coupon.firstOrderOnly) {
        const previousPaidOrders = await db.order.count({ where: { customerId, paymentStatus: "paid" } });
        const pendingFirstOrderUses = await db.couponRedemption.count({ where: {
          couponId: coupon.id, customerId, order: { status: "pending_payment" },
        } });
        if (previousPaidOrders > 0 || pendingFirstOrderUses > 0) throw new BadRequestException({ code: "COUPON_FIRST_ORDER_ONLY", message: "این کد فقط برای اولین سفارش قابل استفاده است." });
      }
    }
    let discountToman = coupon.discountType === "percent"
      ? eligibleSubtotal * BigInt(Math.round(discountValue * 100)) / 10_000n
      : BigInt(discountValue);
    if (coupon.maxDiscountToman !== null && discountToman > coupon.maxDiscountToman) discountToman = coupon.maxDiscountToman;
    if (discountToman > eligibleSubtotal) discountToman = eligibleSubtotal;
    return { id: coupon.id, code: coupon.code, discountToman };
  }

  private async findExistingIdempotentOrder(
    customerId: bigint,
    input: CreateCustomerOrderDto,
    idempotencyKey: string,
  ) {
    const existing = await this.prisma.order.findUnique({
      where: { idempotencyKey },
      include: { items: { select: { variantId: true, quantity: true } } },
    });
    if (!existing) return null;
    if (existing.customerId !== customerId) {
      throw new ConflictException({ code: "IDEMPOTENCY_KEY_ALREADY_USED", message: "این شناسهٔ ثبت سفارش قبلاً استفاده شده است." });
    }

    const requestedItems = new Map<string, number>();
    for (const item of input.items) {
      requestedItems.set(item.variantId, (requestedItems.get(item.variantId) ?? 0) + item.quantity);
    }
    const sameItems = existing.items.length === requestedItems.size
      && existing.items.every((item) => item.variantId !== null
        && requestedItems.get(item.variantId.toString()) === item.quantity);
    const sameAddress = existing.addressId !== null && existing.addressId.toString() === input.addressId;
    const sameCoupon = existing.couponCodeSnapshot === (input.couponCode?.trim().toUpperCase() || null);
    const sameNote = existing.customerNote === (input.customerNote?.trim() || null);
    if (!sameItems || !sameAddress || !sameCoupon || !sameNote) {
      throw new ConflictException({
        code: "IDEMPOTENCY_KEY_REUSED",
        message: "این تلاش ثبت سفارش با اطلاعات متفاوت تکرار شده است؛ صفحه را تازه‌سازی و دوباره تلاش کن.",
      });
    }
    return existing;
  }

  private async releaseExpiredReservations(): Promise<void> {
    const expired = await this.prisma.order.findMany({
      where: { status: "pending_payment", reservationExpiresAt: { lte: new Date() } },
      select: { id: true },
      take: 50,
    });

    for (const candidate of expired) {
      await this.prisma.$transaction(async (tx) => {
        const order = await tx.order.findFirst({
          where: {
            id: candidate.id,
            status: "pending_payment",
            reservationExpiresAt: { lte: new Date() },
          },
          include: { items: { select: { variantId: true, quantity: true } } },
        });
        if (!order) return;

        const claimed = await tx.order.updateMany({
          where: {
            id: order.id,
            status: "pending_payment",
            reservationExpiresAt: { lte: new Date() },
          },
          data: { status: "expired" },
        });
        if (claimed.count !== 1) return;

        await tx.couponRedemption.deleteMany({ where: { orderId: order.id } });

        for (const item of order.items) {
          if (item.variantId === null) continue;
          await tx.productVariant.updateMany({
            where: { id: item.variantId },
            data: { reservedQuantity: { decrement: item.quantity } },
          });
          await tx.inventoryMovement.create({
            data: {
              variantId: item.variantId,
              movementType: "reservation_release",
              quantityDelta: 0,
              reservedDelta: -item.quantity,
              referenceType: "order",
              referenceId: order.id,
              note: `پایان مهلت رزرو سفارش ${order.orderNumber}`,
            },
          });
        }
        await tx.orderStatusHistory.create({
          data: {
            orderId: order.id,
            oldStatus: "pending_payment",
            newStatus: "expired",
            note: "مهلت رزرو سفارش پایان یافت.",
            visibleToCustomer: true,
          },
        });
      });
    }
  }

  private toCreatedOrder(order: {
    orderNumber: string;
    status: string;
    paymentStatus: string;
    totalToman: bigint;
    shippingToman: bigint;
    shippingMethodId?: bigint | null;
    reservationExpiresAt: Date | null;
  }) {
    return {
      data: {
        orderNumber: order.orderNumber,
        status: order.status,
        paymentStatus: order.paymentStatus,
        totalToman: toSafeNumber(order.totalToman),
        shippingToman: toSafeNumber(order.shippingToman),
        shippingConfigured: order.shippingMethodId !== null && order.shippingMethodId !== undefined,
        reservationExpiresAt: order.reservationExpiresAt?.toISOString() ?? null,
        paymentConfigured: Boolean(process.env.PAYMENT_PROVIDER && process.env.PAYMENT_SECRET),
      },
    };
  }
}

function normalizePhone(value: string): string {
  const digits = value.replace(/\D/g, "");
  if (digits.startsWith("0098")) return `+${digits.slice(2)}`;
  if (digits.startsWith("98") && digits.length === 12) return `+${digits}`;
  if (digits.startsWith("0")) return `+98${digits.slice(1)}`;
  return `+98${digits}`;
}

function makeOrderNumber(): string {
  const time = Date.now().toString(36).toUpperCase();
  const random = randomBytes(3).toString("hex").toUpperCase();
  return `PS-${time}-${random}`;
}

function toSafeNumber(value: bigint): number {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) throw new Error("Order total exceeds JavaScript's safe integer range.");
  return number;
}
