import { Body, CallHandler, Controller, ExecutionContext, Get, Injectable, NestInterceptor, Post, Req, UploadedFile, UseGuards, UseInterceptors } from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { diskStorage } from "multer";
import { mkdirSync } from "node:fs";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { unlink } from "node:fs/promises";
import { catchError, from } from "rxjs";
import { uploadRoot } from "../uploads/upload-storage";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminPermissionGuard, RequireAdminPermission } from "../admin-auth/admin-permission.guard";
import { AdminAppReleaseService } from "./admin-app-release.service";
import { PublishAdminAppDto } from "./dto/publish-admin-app.dto";

// DTO validation occurs after disk upload. Remove the file for every rejected request.
@Injectable()
class ReleaseUploadCleanup implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    return next.handle().pipe(catchError((error) => from((async () => {
      const file = context.switchToHttp().getRequest<{ file?: Express.Multer.File }>().file;
      if (file?.path) await unlink(file.path).catch(() => {});
      throw error;
    })())));
  }
}

@Controller("admin/app-releases")
export class AdminAppReleaseController {
  constructor(private readonly releases: AdminAppReleaseService) {}

  @Get("latest")
  latest() { return this.releases.latest(); }

  @Get()
  @UseGuards(AdminSessionGuard, AdminPermissionGuard)
  @RequireAdminPermission("system.release")
  list(@Req() request: AdminRequest) { return this.releases.list(request.admin!); }

  @Post()
  @UseGuards(AdminSessionGuard, AdminPermissionGuard)
  @RequireAdminPermission("system.release")
  @UseInterceptors(FileInterceptor("file", {
    storage: diskStorage({
      destination: (_request, _file, callback) => {
        const path = join(uploadRoot(), "admin-releases");
        try { mkdirSync(path, { recursive: true }); callback(null, path); }
        catch (error) { callback(error as Error, path); }
      },
      filename: (_request, _file, callback) => callback(null, `${randomUUID()}.apk`),
    }), limits: { fileSize: 200 * 1024 * 1024, files: 1 },
  }), ReleaseUploadCleanup)
  publish(@Req() request: AdminRequest, @Body() body: PublishAdminAppDto, @UploadedFile() file?: Express.Multer.File) {
    return this.releases.publish(request.admin!, body, file);
  }
}
