import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from "@nestjs/common";
import { createHash } from "node:crypto";
import type { Request } from "express";
import { PrismaService } from "../database/prisma.service";

export type AuthenticatedCustomer = {
  id: bigint;
  phone: string;
  fullName: string | null;
  email: string | null;
};

export type CustomerRequest = Request & {
  customer?: AuthenticatedCustomer;
  customerSessionId?: bigint;
};

export const CUSTOMER_SESSION_COOKIE = "paniz_customer_session";

@Injectable()
export class CustomerSessionGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<CustomerRequest>();
    const token = readCookie(request.headers.cookie, CUSTOMER_SESSION_COOKIE);
    if (!token || token.length > 100) {
      throw new UnauthorizedException({ code: "CUSTOMER_SESSION_REQUIRED", message: "برای ادامه ابتدا وارد حساب کاربری شو." });
    }

    const tokenHash = createHash("sha256").update(token).digest("hex");
    const session = await this.prisma.customerSession.findUnique({
      where: { tokenHash },
      include: { customer: true },
    });
    const now = new Date();
    if (!session || session.revokedAt || session.expiresAt <= now || session.customer.status !== "active") {
      throw new UnauthorizedException({ code: "CUSTOMER_SESSION_EXPIRED", message: "نشست حساب کاربری منقضی شده؛ دوباره وارد شو." });
    }

    request.customer = {
      id: session.customer.id,
      phone: session.customer.phone,
      fullName: session.customer.fullName,
      email: session.customer.email,
    };
    request.customerSessionId = session.id;
    await this.prisma.customerSession.update({ where: { id: session.id }, data: { lastUsedAt: now } });
    return true;
  }
}

function readCookie(header: string | undefined, name: string): string | null {
  if (!header) return null;
  for (const part of header.split(";")) {
    const [key, ...valueParts] = part.trim().split("=");
    if (key !== name) continue;
    try {
      return decodeURIComponent(valueParts.join("="));
    } catch {
      return null;
    }
  }
  return null;
}
