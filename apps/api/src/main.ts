import "reflect-metadata";
import express from "express";
import type { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import { mkdir } from "node:fs/promises";
import { join } from "node:path";
import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { AppModule } from "./app.module";
import { uploadRoot } from "./uploads/upload-storage";
import { AdminNotificationGateway } from "./admin-notifications/admin-notification.gateway";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.getHttpAdapter().getInstance().set("trust proxy", 1);
  const config = app.get(ConfigService);

  app.setGlobalPrefix("api/v1");
  app.use(helmet());
  await mkdir(join(uploadRoot(), "products"), { recursive: true });
  app.use(
    "/uploads",
    (_request: Request, response: Response, next: NextFunction) => {
      response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
      next();
    },
    express.static(uploadRoot(), { dotfiles: "deny", immutable: true, maxAge: "30d" }),
  );
  const configuredOrigins = config
    .getOrThrow<string>("WEB_ORIGINS")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);
  const productionOrigins =
    config.get<string>("NODE_ENV") === "production"
      ? ["https://panizstyle.ir", "https://www.panizstyle.ir"]
      : [];
  app.enableCors({
    origin: [...new Set([...configuredOrigins, ...productionOrigins])],
    credentials: true,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    }),
  );

  if (config.get<string>("NODE_ENV") !== "production") {
    const openApiConfig = new DocumentBuilder()
      .setTitle("پانیذ | API")
      .setDescription("API نسخه‌دار فروشگاه پانیذ")
      .setVersion("1.0.0")
      .addBearerAuth({ type: "http", scheme: "bearer", bearerFormat: "opaque" }, "admin-session")
      .build();
    const openApiDocument = SwaggerModule.createDocument(app, openApiConfig);
    SwaggerModule.setup("api/docs", app, openApiDocument);
  }

  app.enableShutdownHooks();
  await app.get(AdminNotificationGateway).attach(app.getHttpServer());
  await app.listen(config.get<number>("PORT", 4000), "0.0.0.0");
}

void bootstrap();
