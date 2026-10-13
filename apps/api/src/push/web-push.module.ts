import { Module } from "@nestjs/common";
import { PrismaModule } from "../database/prisma.module";
import { WebPushService } from "./web-push.service";

@Module({ imports: [PrismaModule], providers: [WebPushService], exports: [WebPushService] })
export class WebPushModule {}
