import { Module } from "@nestjs/common";
import { AdminAuthModule } from "../admin-auth/admin-auth.module";
import { AdminNotificationsModule } from "../admin-notifications/admin-notifications.module";
import { PrismaModule } from "../database/prisma.module";
import { WebPushModule } from "../push/web-push.module";
import { AdminSupportController } from "./support.controller";
import { SupportService } from "./support.service";

@Module({ imports: [PrismaModule, AdminAuthModule, AdminNotificationsModule, WebPushModule], controllers: [AdminSupportController], providers: [SupportService], exports: [SupportService] })
export class SupportModule {}
