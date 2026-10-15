import { Module } from "@nestjs/common";
import { PrismaModule } from "../database/prisma.module";
import { PublicWebPushController } from "./public-web-push.controller";
import { WebPushService } from "./web-push.service";

@Module({ imports: [PrismaModule], controllers: [PublicWebPushController], providers: [WebPushService], exports: [WebPushService] })
export class WebPushModule {}
