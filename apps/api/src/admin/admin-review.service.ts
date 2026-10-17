import { BadRequestException, Injectable, NotFoundException } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";
import { requireAdminPermission } from "../admin-auth/admin-permissions";

const REVIEW_STATUSES = ["pending", "approved", "rejected"] as const;

@Injectable()
export class AdminReviewService {
  constructor(private readonly prisma: PrismaService) {}

  async list(statusText?: string) {
    const status = statusText?.trim() || "pending";
    if (status !== "all" && !REVIEW_STATUSES.includes(status as (typeof REVIEW_STATUSES)[number])) {
      throw new BadRequestException({ code: "REVIEW_STATUS_INVALID", message: "وضعیت نظر معتبر نیست." });
    }
    const reviews = await this.prisma.review.findMany({
      where: status === "all" ? {} : { status },
      orderBy: [{ createdAt: "desc" }, { id: "desc" }],
      take: 200,
      select: {
        id: true,
        rating: true,
        title: true,
        body: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        product: { select: { id: true, name: true, slug: true } },
        customer: { select: { fullName: true } },
        orderItem: {
          select: {
            colorNameSnapshot: true,
            sizeLabelSnapshot: true,
            order: { select: { orderNumber: true, placedAt: true } },
          },
        },
      },
    });
    return { data: reviews.map((review) => ({
      id: review.id.toString(),
      rating: review.rating,
      title: review.title,
      body: review.body,
      status: review.status,
      createdAt: review.createdAt.toISOString(),
      updatedAt: review.updatedAt.toISOString(),
      product: { id: review.product.id.toString(), name: review.product.name, slug: review.product.slug },
      customerName: review.customer.fullName?.trim() || "مشتری تأییدشده",
      color: review.orderItem.colorNameSnapshot,
      size: review.orderItem.sizeLabelSnapshot,
      orderNumber: review.orderItem.order.orderNumber,
      purchasedAt: review.orderItem.order.placedAt.toISOString(),
    })) };
  }

  async updateStatus(admin: AuthenticatedAdmin, idText: string, status: (typeof REVIEW_STATUSES)[number]) {
    requireAdminPermission(admin, "products.edit");
    if (!/^\d{1,20}$/.test(idText)) {
      throw new BadRequestException({ code: "REVIEW_ID_INVALID", message: "شناسهٔ نظر معتبر نیست." });
    }
    const id = BigInt(idText);
    if (id <= 0n || id > 18446744073709551615n) {
      throw new BadRequestException({ code: "REVIEW_ID_INVALID", message: "شناسهٔ نظر معتبر نیست." });
    }
    const current = await this.prisma.review.findUnique({
      where: { id },
      select: { status: true, product: { select: { name: true } } },
    });
    if (!current) throw new NotFoundException({ code: "REVIEW_NOT_FOUND", message: "نظر پیدا نشد." });
    if (current.status === status) return { data: { id: id.toString(), status } };

    await this.prisma.$transaction(async (tx) => {
      await tx.review.update({ where: { id }, data: { status } });
      await tx.adminAuditLog.create({
        data: {
          adminId: admin.id,
          action: "product_review.status_changed",
          entityType: "product_review",
          entityId: id,
          details: { productName: current.product.name, previousStatus: current.status, status },
        },
      });
    });
    return { data: { id: id.toString(), status } };
  }
}
