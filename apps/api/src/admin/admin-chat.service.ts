import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { randomUUID } from "node:crypto";
import { AdminNotificationService } from "../admin-notifications/admin-notification.service";
import { PrismaService } from "../database/prisma.service";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";

@Injectable()
export class AdminChatService {
  constructor(private readonly prisma: PrismaService, private readonly notifications: AdminNotificationService) {}

  async contacts(admin: AuthenticatedAdmin) {
    const where = admin.role === "owner" ? { isActive: true, role: { not: "owner" } } : { isActive: true, role: "owner" };
    const contacts = await this.prisma.adminUser.findMany({
      where, orderBy: [{ fullName: "asc" }, { id: "asc" }],
      select: { id: true, fullName: true, username: true, role: true, avatarPath: true },
    });
    const items = await Promise.all(contacts.map(async (contact) => {
      const [last, unreadCount] = await Promise.all([
        this.prisma.adminChatMessage.findFirst({ where: { hiddenFor: { none: { adminId: admin.id } }, OR: [
          { senderAdminId: admin.id, recipientAdminId: contact.id },
          { senderAdminId: contact.id, recipientAdminId: admin.id },
        ] }, orderBy: [{ createdAt: "desc" }, { id: "desc" }], select: { body: true, createdAt: true } }),
        this.prisma.adminChatMessage.count({ where: { senderAdminId: contact.id, recipientAdminId: admin.id, readAt: null } }),
      ]);
      return { ...contact, id: contact.id.toString(), lastMessage: last?.body ?? null, lastMessageAt: last?.createdAt.toISOString() ?? null, unreadCount };
    }));
    return { data: items };
  }

  async messages(admin: AuthenticatedAdmin, contactIdText: string) {
    const contactId = parseId(contactIdText);
    const contact = await this.prisma.adminUser.findFirst({
      where: { id: contactId, isActive: true, ...(admin.role === "owner" ? { role: { not: "owner" } } : { role: "owner" }) },
      select: { id: true },
    });
    if (!contact) throw new NotFoundException({ code: "ADMIN_CHAT_CONTACT_NOT_FOUND", message: "گفت‌وگوی مدیر پیدا نشد." });
    await this.prisma.adminChatMessage.updateMany({ where: { senderAdminId: contactId, recipientAdminId: admin.id, readAt: null }, data: { readAt: new Date() } });
    const rows = await this.prisma.adminChatMessage.findMany({
      where: { hiddenFor: { none: { adminId: admin.id } }, OR: [ { senderAdminId: admin.id, recipientAdminId: contactId }, { senderAdminId: contactId, recipientAdminId: admin.id } ] },
      orderBy: [{ createdAt: "asc" }, { id: "asc" }], take: 150,
      include: { sender: { select: { id: true, fullName: true, avatarPath: true, role: true } } },
    });
    return { data: rows.map((row) => ({ id: row.id.toString(), senderAdminId: row.senderAdminId.toString(), recipientAdminId: row.recipientAdminId.toString(), senderName: row.sender.fullName, senderAvatarPath: row.sender.avatarPath, senderRole: row.sender.role, body: row.body, broadcast: row.broadcastGroupId !== null, createdAt: row.createdAt.toISOString(), editedAt: row.editedAt?.toISOString() ?? null, readAt: row.readAt?.toISOString() ?? null })) };
  }

  async send(admin: AuthenticatedAdmin, input: { recipientAdminId?: string; body: string; broadcast?: boolean }) {
    const body = input.body?.trim();
    if (!body || body.length > 4000) throw new BadRequestException({ code: "ADMIN_MESSAGE_REQUIRED", message: "متن پیام باید بین ۱ تا ۴۰۰۰ نویسه باشد." });
    const groupId = input.broadcast === true ? randomUUID() : null;
    const recipients: Array<{ id: bigint; fullName: string }> = [];
    if (admin.role === "owner" && input.broadcast === true) {
      recipients.push(...await this.prisma.adminUser.findMany({ where: { isActive: true, role: { not: "owner" }, id: { not: admin.id } }, select: { id: true, fullName: true } }));
      if (!recipients.length) throw new BadRequestException({ code: "ADMIN_CHAT_NO_RECIPIENTS", message: "ادمین فعالی برای ارسال پیام گروهی پیدا نشد." });
    } else if (admin.role === "owner") {
      const id = parseId(input.recipientAdminId ?? "");
      const recipient = await this.prisma.adminUser.findFirst({ where: { id, isActive: true, role: { not: "owner" } }, select: { id: true, fullName: true } });
      if (!recipient) throw new NotFoundException({ code: "ADMIN_CHAT_CONTACT_NOT_FOUND", message: "ادمین انتخاب‌شده پیدا نشد." });
      recipients.push(recipient);
    } else {
      const owner = await this.prisma.adminUser.findFirst({ where: { role: "owner", isActive: true }, orderBy: { id: "asc" }, select: { id: true, fullName: true } });
      if (!owner) throw new NotFoundException({ code: "ADMIN_CHAT_OWNER_NOT_FOUND", message: "حساب سوپرادمین پیدا نشد." });
      recipients.push(owner);
    }
    const sent = [];
    for (const recipient of recipients) {
      const row = await this.prisma.adminChatMessage.create({ data: {
        senderAdminId: admin.id, recipientAdminId: recipient.id, broadcastGroupId: groupId, body,
      }, include: { sender: { select: { fullName: true, avatarPath: true, role: true } } } });
      sent.push(row);
      await this.notifications.notifyAdmin(recipient.id, {
        type: "admin_message", title: groupId ? "پیام گروهی از سوپرادمین" : "پیام تازه از ادمین",
        body: body.slice(0, 350), entityType: "admin_chat", entityId: row.id, dedupeKey: `admin-chat:${row.id}`,
      });
    }
    return { data: sent.map((row) => ({ id: row.id.toString(), senderAdminId: row.senderAdminId.toString(), recipientAdminId: row.recipientAdminId.toString(), senderName: row.sender.fullName, senderAvatarPath: row.sender.avatarPath, body: row.body, broadcast: groupId !== null, createdAt: row.createdAt.toISOString(), readAt: null })) };
  }

  async edit(admin: AuthenticatedAdmin, idText: string, inputBody: string) {
    const body = inputBody.trim();
    if (!body || body.length > 4000) throw new BadRequestException({ code: "ADMIN_MESSAGE_REQUIRED", message: "متن پیام باید بین ۱ تا ۴۰۰۰ نویسه باشد." });
    const id = parseId(idText);
    const result = await this.prisma.adminChatMessage.updateMany({
      where: { id, senderAdminId: admin.id },
      data: { body, editedAt: new Date() },
    });
    if (result.count !== 1) throw new NotFoundException({ code: "ADMIN_CHAT_MESSAGE_NOT_FOUND", message: "پیام قابل ویرایش پیدا نشد." });
    return { data: { id: id.toString(), body, editedAt: new Date().toISOString() } };
  }

  async remove(admin: AuthenticatedAdmin, idText: string, forEveryone: boolean) {
    const id = parseId(idText);
    const message = await this.prisma.adminChatMessage.findFirst({
      where: { id, OR: [{ senderAdminId: admin.id }, { recipientAdminId: admin.id }] },
      select: { id: true, senderAdminId: true },
    });
    if (!message) throw new NotFoundException({ code: "ADMIN_CHAT_MESSAGE_NOT_FOUND", message: "پیام پیدا نشد." });
    if (forEveryone) {
      if (message.senderAdminId !== admin.id) throw new BadRequestException({ code: "ADMIN_CHAT_DELETE_FORBIDDEN", message: "فقط فرستنده می‌تواند پیام را برای همه حذف کند." });
      await this.prisma.adminChatMessage.delete({ where: { id } });
    } else {
      await this.prisma.adminChatMessageHide.upsert({
        where: { messageId_adminId: { messageId: id, adminId: admin.id } },
        create: { messageId: id, adminId: admin.id },
        update: {},
      });
    }
    return { data: { deleted: true, forEveryone } };
  }
}

function parseId(value: string): bigint {
  if (!/^\d{1,20}$/.test(value) || BigInt(value) < 1n) throw new BadRequestException({ code: "ADMIN_CHAT_CONTACT_REQUIRED", message: "ادمین گفت‌وگو را انتخاب کن." });
  return BigInt(value);
}
