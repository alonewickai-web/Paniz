import { Injectable, ServiceUnavailableException } from "@nestjs/common";
import { PrismaService } from "../database/prisma.service";

@Injectable()
export class HealthService {
  constructor(private readonly prisma: PrismaService) {}

  live(): { status: string; timestamp: string } {
    return { status: "live", timestamp: new Date().toISOString() };
  }

  async ready(): Promise<{ status: string; database: string; timestamp: string }> {
    try {
      await this.prisma.$queryRaw`SELECT 1`;
      return { status: "ready", database: "connected", timestamp: new Date().toISOString() };
    } catch {
      throw new ServiceUnavailableException({
        code: "DATABASE_UNAVAILABLE",
        message: "اتصال به دیتابیس برقرار نیست",
      });
    }
  }
}
