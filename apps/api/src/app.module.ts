import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { APP_FILTER, APP_GUARD } from "@nestjs/core";
import { ThrottlerGuard, ThrottlerModule } from "@nestjs/throttler";
import { CatalogModule } from "./catalog/catalog.module";
import { PrismaModule } from "./database/prisma.module";
import { HealthModule } from "./health/health.module";
import { OrdersModule } from "./orders/orders.module";
import { AdminModule } from "./admin/admin.module";
import { CustomerModule } from "./customer/customer.module";
import { ApiExceptionFilter } from "./common/filters/api-exception.filter";

function validateEnvironment(config: Record<string, unknown>): Record<string, unknown> {
  const port = Number(config.PORT ?? 4000);
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("PORT must be an integer between 1 and 65535.");
  }

  const databaseUrl = String(config.DATABASE_URL ?? "");
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(databaseUrl);
  } catch {
    throw new Error("DATABASE_URL must be a valid MySQL connection URL.");
  }

  if (parsedUrl.protocol !== "mysql:" || !parsedUrl.hostname || !parsedUrl.pathname.slice(1)) {
    throw new Error("DATABASE_URL must use mysql:// and include a database name.");
  }

  if (!config.WEB_ORIGINS) {
    throw new Error("WEB_ORIGINS must contain at least one allowed browser origin.");
  }

  return { ...config, PORT: port };
}

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnvironment }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 120 }]),
    PrismaModule,
    HealthModule,
    CatalogModule,
    OrdersModule,
    CustomerModule,
    AdminModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_FILTER, useClass: ApiExceptionFilter },
  ],
})
export class AppModule {}
