import { BadRequestException, Body, Controller, Delete, Get, HttpCode, HttpStatus, Patch, Post, Req, UploadedFile, UseGuards, UseInterceptors } from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { memoryStorage } from "multer";
import { mkdir, writeFile, unlink } from "node:fs/promises";
import { randomUUID } from "node:crypto";
import { basename, join } from "node:path";
import { uploadRoot } from "../uploads/upload-storage";
import { UpdateAdminProfileDto } from "../admin/dto/update-admin-profile.dto";
import { ApiBearerAuth, ApiBody, ApiOperation, ApiTags } from "@nestjs/swagger";
import { Throttle } from "@nestjs/throttler";
import { AdminAuthService } from "./admin-auth.service";
import { AdminSessionGuard, AdminRequest } from "./admin-session.guard";
import { AdminLoginDto } from "./dto/admin-login.dto";
import { UpdateAdminCredentialsDto } from "./dto/update-admin-credentials.dto";

@ApiTags("مدیریت فروشگاه | احراز هویت")
@Controller("admin/auth")
export class AdminAuthController {
  constructor(private readonly auth: AdminAuthService) {}

  @Post("login")
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiOperation({ summary: "ورود مدیر و دریافت نشست قابل ابطال" })
  @ApiBody({ type: AdminLoginDto })
  login(@Body() body: AdminLoginDto) {
    return this.auth.login(body);
  }

  @Get("me")
  @UseGuards(AdminSessionGuard)
  @ApiBearerAuth("admin-session")
  @ApiOperation({ summary: "نمایش هویت مدیر واردشده" })
  me(@Req() request: AdminRequest) {
    return this.auth.me(request);
  }

  @Post("logout")
  @HttpCode(HttpStatus.OK)
  @UseGuards(AdminSessionGuard)
  @ApiBearerAuth("admin-session")
  @ApiOperation({ summary: "باطل‌کردن نشست مدیر جاری" })
  logout(@Req() request: AdminRequest) {
    return this.auth.logout(request);
  }

  @Patch("credentials")
  @UseGuards(AdminSessionGuard)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiBearerAuth("admin-session")
  @ApiOperation({ summary: "تغییر نام کاربری یا گذرواژه پس از تأیید گذرواژهٔ فعلی" })
  @ApiBody({ type: UpdateAdminCredentialsDto })
  updateCredentials(@Body() body: UpdateAdminCredentialsDto, @Req() request: AdminRequest) {
    return this.auth.updateCredentials(body, request);
  }

  @Patch("profile")
  @UseGuards(AdminSessionGuard)
  updateProfile(@Body() body: UpdateAdminProfileDto, @Req() request: AdminRequest) {
    return this.auth.updateProfile(body, request);
  }

  @Post("profile/avatar")
  @UseGuards(AdminSessionGuard)
  @UseInterceptors(FileInterceptor("file", { storage: memoryStorage(), limits: { fileSize: 1024 * 1024, files: 1 } }))
  async uploadAvatar(@Req() request: AdminRequest, @UploadedFile() file?: Express.Multer.File) {
    if (!file) throw new BadRequestException({ code: "AVATAR_REQUIRED", message: "تصویر پروفایل را انتخاب کنید." });
    const b = file.buffer;
    const extension = b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff ? ".jpg"
      : b.subarray(0, 8).equals(Buffer.from([137, 80, 78, 71, 13, 10, 26, 10])) ? ".png"
      : b.subarray(0, 4).toString() === "RIFF" && b.subarray(8, 12).toString() === "WEBP" ? ".webp" : null;
    if (!extension) throw new BadRequestException({ code: "AVATAR_IMAGE_INVALID", message: "تصویر باید از نوع JPG، PNG یا WebP باشد." });
    const filename = `${randomUUID()}${extension}`;
    const directory = join(uploadRoot(), "admin-avatars");
    await mkdir(directory, { recursive: true });
    const path = join(directory, filename);
    await writeFile(path, b, { flag: "wx" });
    try { return await this.auth.updateProfile({}, request, `/uploads/admin-avatars/${filename}`); }
    catch (error) { await unlink(path).catch(() => {}); throw error; }
  }

  @Delete("profile/avatar")
  @UseGuards(AdminSessionGuard)
  async deleteAvatar(@Req() request: AdminRequest) {
    const oldPath = request.admin?.avatarPath;
    const result = await this.auth.updateProfile({}, request, null);
    if (oldPath && /^\/uploads\/admin-avatars\/[a-z0-9-]+\.(?:jpg|png|webp)$/i.test(oldPath)) {
      await unlink(join(uploadRoot(), "admin-avatars", basename(oldPath))).catch(() => undefined);
    }
    return result;
  }
}
