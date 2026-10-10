import "reflect-metadata";
import helmet from "helmet";
import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { AppModule } from "./app.module";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);

  app.setGlobalPrefix("api/v1");
  app.use(helmet());
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
      .setTitle("PanizStyle API")
      .setDescription("API نسخه‌دار فروشگاه PanizStyle")
      .setVersion("1.0.0")
      .addBearerAuth({ type: "http", scheme: "bearer", bearerFormat: "opaque" }, "admin-session")
      .build();
    const openApiDocument = SwaggerModule.createDocument(app, openApiConfig);
    SwaggerModule.setup("api/docs", app, openApiDocument);
  }

  app.enableShutdownHooks();
  await app.listen(config.get<number>("PORT", 4000), "0.0.0.0");
}

void bootstrap();
