import { BadRequestException, ConflictException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";
import { AdminNotificationService } from "../admin-notifications/admin-notification.service";
import { WebPushService } from "../push/web-push.service";
import { CreateTicketDto, SupportMessageDto } from "./dto/create-ticket.dto";
import { CreateReturnDto, UpdateReturnDto } from "./dto/create-return.dto";

@Injectable()
export class SupportService {
  constructor(private readonly prisma: PrismaService, private readonly notifications: AdminNotificationService, private readonly push: WebPushService) {}

  pushPublicKey() { return { data: { publicKey: this.push.publicKey() } }; }

  async savePushSubscription(customerId: bigint, value: { endpoint: string; keys: { p256dh: string; auth: string } }) {
    return { data: await this.push.saveSubscription(customerId, value) };
  }

  async removePushSubscription(customerId: bigint, endpoint: string) {
    await this.push.removeSubscription(customerId, endpoint);
    return { data: { removed: true } };
  }

  async subscribeBackInStock(customerId: bigint, variantIdText: string) {
    const variantId = parseId(variantIdText);
    const variant = await this.prisma.productVariant.findFirst({
      where: { id: variantId, isActive: true, product: { status: "published", deletedAt: null } },
      select: { stockQuantity: true, reservedQuantity: true },
    });
    if (!variant) throw new NotFoundException({ code: "VARIANT_NOT_FOUND", message: "این انتخاب محصول پیدا نشد." });
    if (variant.stockQuantity - variant.reservedQuantity > 0) throw new BadRequestException({ code: "VARIANT_IN_STOCK", message: "این انتخاب در حال حاضر موجود است." });
    await this.prisma.backInStockSubscription.upsert({
      where: { customerId_variantId: { customerId, variantId } },
      create: { customerId, variantId }, update: { createdAt: new Date(), notifiedAt: null },
    });
    return { data: { subscribed: true } };
  }

  async createTicket(customerId: bigint, input: CreateTicketDto) {
    const ticket = await this.prisma.customerSupportTicket.create({
      data: {
        customerId, subject: input.subject.trim(),
        messages: { create: { senderType: "customer", customerId, body: input.message.trim(), imagePath: input.imagePath ?? null } },
      },
      include: { messages: { orderBy: { createdAt: "asc" } } },
    });
    await this.notifications.notifyOwners({
      type: "customer_message", title: "درخواست پشتیبانی تازه",
      body: `${ticket.subject} · مشتری شماره ${customerId.toString()}`,
      entityType: "support_ticket", entityId: ticket.id,
      dedupeKey: `support-ticket:${ticket.id}`,
    });
    return { data: serializeTicket(ticket) };
  }

  async customerTickets(customerId: bigint) {
    const tickets = await this.prisma.customerSupportTicket.findMany({
      where: { customerId }, orderBy: { lastMessageAt: "desc" }, take: 50,
      include: { messages: { orderBy: { createdAt: "asc" } } },
    });
    return { data: tickets.map(serializeTicket) };
  }

  async customerReply(customerId: bigint, ticketIdText: string, input: SupportMessageDto) {
    const ticketId = parseId(ticketIdText);
    const ticket = await this.prisma.customerSupportTicket.findFirst({ where: { id: ticketId, customerId }, select: { id: true, status: true } });
    if (!ticket) throw new NotFoundException({ code: "SUPPORT_TICKET_NOT_FOUND", message: "گفت‌وگوی پشتیبانی پیدا نشد." });
    if (ticket.status === "closed") throw new ConflictException({ code: "SUPPORT_TICKET_CLOSED", message: "این تیکت بسته شده است و امکان ارسال پیام ندارد." });
    await this.prisma.$transaction(async (transaction) => {
      await transaction.customerSupportMessage.create({ data: { ticketId, senderType: "customer", customerId, body: input.body.trim(), imagePath: input.imagePath ?? null } });
      const updated = await transaction.customerSupportTicket.updateMany({ where: { id: ticketId, customerId, status: { not: "closed" } }, data: { status: "open", lastMessageAt: new Date() } });
      if (updated.count === 0) throw new ConflictException({ code: "SUPPORT_TICKET_CLOSED", message: "این تیکت بسته شده است و امکان ارسال پیام ندارد." });
    });
    await this.notifications.notifyOwners({ type: "customer_message", title: "پیام تازه در پشتیبانی", body: input.body.trim().slice(0, 350), entityType: "support_ticket", entityId: ticketId });
    return { data: { sent: true } };
  }

  async createReturn(customerId: bigint, orderNumber: string, input: CreateReturnDto) {
    const order = await this.prisma.order.findFirst({ where: { orderNumber, customerId }, select: { id: true, status: true, paymentStatus: true, orderNumber: true } });
    if (!order) throw new NotFoundException({ code: "ORDER_NOT_FOUND", message: "سفارش پیدا نشد." });
    if (order.status !== "delivered" || order.paymentStatus !== "paid") throw new BadRequestException({ code: "ORDER_NOT_RETURNABLE", message: "درخواست مرجوعی پس از تحویل و پرداخت کامل سفارش ثبت می‌شود." });
    try {
      const item = await this.prisma.orderReturnRequest.create({ data: {
        orderId: order.id, customerId, reason: input.reason.trim(), iban: input.iban.trim().toUpperCase(), cardNumber: input.cardNumber.replace(/\D/g, ""),
      } });
      await this.notifications.notifyOwners({ type: "customer_message", title: "درخواست مرجوعی تازه", body: `سفارش ${order.orderNumber} · ${input.reason.trim().slice(0, 260)}`, entityType: "return_request", entityId: item.id, dedupeKey: `return:${item.id}` });
      return { data: serializeReturn(item) };
    } catch (error) {
      if ((error as { code?: string }).code === "P2002") throw new ConflictException({ code: "RETURN_ALREADY_REQUESTED", message: "برای این سفارش قبلاً درخواست مرجوعی ثبت شده است." });
      throw error;
    }
  }

  async customerReturns(customerId: bigint) {
    const rows = await this.prisma.orderReturnRequest.findMany({
      where: { customerId }, orderBy: { requestedAt: "desc" },
      include: { order: { select: { orderNumber: true, totalToman: true } } },
    });
    return { data: rows.map((row) => ({ ...serializeReturn(row), orderNumber: row.order.orderNumber, refundAmountToman: safeNumber(row.order.totalToman) })) };
  }

  async adminTickets() {
    const tickets = await this.prisma.customerSupportTicket.findMany({
      orderBy: [{ status: "asc" }, { lastMessageAt: "desc" }], take: 100,
      include: { customer: { select: { phone: true, fullName: true } }, messages: { orderBy: { createdAt: "asc" } } },
    });
    return { data: tickets.map((ticket) => ({ ...serializeTicket(ticket), customer: ticket.customer })) };
  }

  async adminReply(adminId: bigint, ticketIdText: string, input: SupportMessageDto) {
    const ticketId = parseId(ticketIdText);
    const ticket = await this.prisma.customerSupportTicket.findUnique({ where: { id: ticketId }, select: { id: true, customerId: true, status: true } });
    if (!ticket) throw new NotFoundException({ code: "SUPPORT_TICKET_NOT_FOUND", message: "گفت‌وگوی پشتیبانی پیدا نشد." });
    if (ticket.status === "closed") throw new ConflictException({ code: "SUPPORT_TICKET_CLOSED", message: "این تیکت بسته شده است و امکان ارسال پیام ندارد." });
    await this.prisma.$transaction(async (transaction) => {
      await transaction.customerSupportMessage.create({ data: { ticketId, senderType: "admin", adminId, body: input.body.trim(), imagePath: input.imagePath ?? null } });
      const updated = await transaction.customerSupportTicket.updateMany({ where: { id: ticketId, status: { not: "closed" } }, data: { status: "waiting_customer", lastMessageAt: new Date() } });
      if (updated.count === 0) throw new ConflictException({ code: "SUPPORT_TICKET_CLOSED", message: "این تیکت بسته شده است و امکان ارسال پیام ندارد." });
    });
    await this.push.notifyCustomer(ticket.customerId, "پاسخ پشتیبانی پانیذ", input.body.trim().slice(0, 160), "/account#support");
    return { data: { sent: true } };
  }

  async closeTicket(ticketIdText: string) {
    const ticketId = parseId(ticketIdText);
    const ticket = await this.prisma.customerSupportTicket.findUnique({ where: { id: ticketId }, select: { id: true, customerId: true, subject: true } });
    if (!ticket) throw new NotFoundException({ code: "SUPPORT_TICKET_NOT_FOUND", message: "گفت‌وگوی پشتیبانی پیدا نشد." });
    const updated = await this.prisma.customerSupportTicket.updateMany({
      where: { id: ticketId, status: { not: "closed" } },
      data: { status: "closed", lastMessageAt: new Date() },
    });
    if (updated.count > 0) {
      await this.push.notifyCustomer(ticket.customerId, "تیکت بسته شد", `درخواست «${ticket.subject}» بسته شد.`, "/account#support");
    }
    return { data: { status: "closed", alreadyClosed: updated.count === 0 } };
  }

  async adminReturns() {
    const rows = await this.prisma.orderReturnRequest.findMany({
      orderBy: { requestedAt: "desc" }, take: 100,
      include: { order: { select: { orderNumber: true, totalToman: true } }, customer: { select: { fullName: true, phone: true } } },
    });
    return { data: rows.map((row) => ({ ...serializeReturn(row), orderNumber: row.order.orderNumber, refundAmountToman: safeNumber(row.order.totalToman), customer: row.customer })) };
  }

  async updateReturn(idText: string, input: UpdateReturnDto) {
    const id = parseId(idText);
    const current = await this.prisma.orderReturnRequest.findUnique({ where: { id }, select: { id: true, customerId: true, receivedAt: true, status: true } });
    if (!current) throw new NotFoundException({ code: "RETURN_NOT_FOUND", message: "درخواست مرجوعی پیدا نشد." });
    if (input.status === "refunded" && !current.receivedAt && current.status !== "received") throw new BadRequestException({ code: "RETURN_ITEM_NOT_RECEIVED", message: "بازپرداخت فقط پس از دریافت کامل کالای مرجوعی ثبت می‌شود." });
    const updated = await this.prisma.orderReturnRequest.update({ where: { id }, data: {
      status: input.status, adminNote: input.adminNote.trim() || null,
      ...(input.status === "received" ? { receivedAt: new Date() } : {}),
      ...(input.status === "refunded" ? { refundedAt: new Date() } : {}),
    } });
    const statusTitle = input.status === "received" ? "کالای مرجوعی دریافت شد" : input.status === "refunded" ? "بازپرداخت انجام شد" : "وضعیت مرجوعی تغییر کرد";
    const body = input.adminNote.trim() || statusTitle;
    await this.push.notifyCustomer(current.customerId, statusTitle, body, "/account#orders");
    return { data: serializeReturn(updated) };
  }

  async attachReturnReceipt(idText: string, imagePath: string) {
    const id = parseId(idText);
    const current = await this.prisma.orderReturnRequest.findUnique({ where: { id }, select: { id: true, customerId: true, status: true } });
    if (!current) throw new NotFoundException({ code: "RETURN_NOT_FOUND", message: "درخواست مرجوعی پیدا نشد." });
    if (current.status !== "received" && current.status !== "refunded") throw new BadRequestException({ code: "RETURN_ITEM_NOT_RECEIVED", message: "رسید واریز پس از دریافت کالای مرجوعی ثبت می‌شود." });
    const updated = await this.prisma.orderReturnRequest.update({ where: { id }, data: { refundReceiptPath: imagePath } });
    await this.push.notifyCustomer(current.customerId, "رسید بازپرداخت آماده است", "تصویر رسید واریز در وضعیت مرجوعی سفارش شما ثبت شد.", "/account#orders");
    return { data: serializeReturn(updated) };
  }
}

function serializeTicket(ticket: { id: bigint; subject: string; status: string; createdAt: Date; lastMessageAt: Date; messages: Array<{ id: bigint; senderType: string; body: string; imagePath: string | null; createdAt: Date }> }) {
  return { id: ticket.id.toString(), subject: ticket.subject, status: ticket.status, createdAt: ticket.createdAt.toISOString(), lastMessageAt: ticket.lastMessageAt.toISOString(), messages: ticket.messages.map((message) => ({ id: message.id.toString(), senderType: message.senderType, body: message.body, imagePath: message.imagePath, createdAt: message.createdAt.toISOString() })) };
}

function serializeReturn(row: { id: bigint; orderId: bigint; reason: string; iban: string; cardNumber: string; status: string; adminNote: string | null; refundReceiptPath: string | null; requestedAt: Date; receivedAt: Date | null; refundedAt: Date | null }) {
  return { id: row.id.toString(), orderId: row.orderId.toString(), reason: row.reason, iban: row.iban, cardNumber: row.cardNumber, status: row.status, adminNote: row.adminNote, refundReceiptPath: row.refundReceiptPath, requestedAt: row.requestedAt.toISOString(), receivedAt: row.receivedAt?.toISOString() ?? null, refundedAt: row.refundedAt?.toISOString() ?? null, returnShippingPaidByCustomer: true };
}

function parseId(raw: string) {
  if (!/^\d{1,20}$/.test(raw) || BigInt(raw) < 1n) throw new BadRequestException({ code: "INVALID_ID", message: "شناسه معتبر نیست." });
  return BigInt(raw);
}

function safeNumber(value: bigint) {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) throw new Error("Money total exceeds the JavaScript safe integer range.");
  return number;
}
