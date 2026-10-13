import { BadRequestException, ConflictException, Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { createHash } from "node:crypto";
import { createReadStream } from "node:fs";
import { open, unlink } from "node:fs/promises";
import { PrismaService } from "../database/prisma.service";
import { AuthenticatedAdmin } from "../admin-auth/admin-session.guard";
import { requireAdminPermission } from "../admin-auth/admin-permissions";
import { PublishAdminAppDto } from "./dto/publish-admin-app.dto";

@Injectable()
export class AdminAppReleaseService {
  constructor(private readonly prisma: PrismaService) {}

  async latest() {
    const release = await this.prisma.adminAppRelease.findFirst({ where: { isCurrent: true }, orderBy: { versionCode: "desc" } });
    return { data: release ? serializeRelease(release) : null };
  }

  async list(admin: AuthenticatedAdmin) {
    requireAdminPermission(admin, "system.release");
    const rows = await this.prisma.adminAppRelease.findMany({ orderBy: { versionCode: "desc" }, take: 30 });
    return { data: rows.map(serializeRelease) };
  }

  async publish(admin: AuthenticatedAdmin, input: PublishAdminAppDto, file?: Express.Multer.File) {
    requireAdminPermission(admin, "system.release");
    if (!file) throw new BadRequestException({ code: "APK_REQUIRED", message: "فایل APK را انتخاب کنید." });
    try {
      await validateApk(file.path);
      const hash = createHash("sha256");
      for await (const chunk of createReadStream(file.path)) hash.update(chunk);
      const sha256 = hash.digest("hex");
      const release = await this.prisma.$transaction(async (tx) => {
        const latest = await tx.adminAppRelease.findFirst({ orderBy: { versionCode: "desc" } });
        if (latest && input.versionCode <= latest.versionCode) {
          throw new ConflictException({ code: "APK_VERSION_MUST_INCREASE", message: "شمارهٔ ساخت باید از همهٔ نسخه‌های قبلی بیشتر باشد." });
        }
        await tx.adminAppRelease.updateMany({ where: { isCurrent: true }, data: { isCurrent: false } });
        const created = await tx.adminAppRelease.create({ data: {
          versionName: input.versionName, versionCode: input.versionCode,
          filePath: `/uploads/admin-releases/${file.filename}`, fileSizeBytes: BigInt(file.size), sha256,
          releaseNotes: input.releaseNotes?.trim() || null, isCurrent: true, createdByAdminId: admin.id,
        } });
        await tx.adminAuditLog.create({ data: {
          adminId: admin.id, action: "admin.app_release_published", entityType: "app_release", entityId: created.id,
          details: { versionName: created.versionName, versionCode: created.versionCode, sha256 },
        } });
        return created;
      }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
      return { data: serializeRelease(release) };
    } catch (error) {
      await unlink(file.path).catch(() => {});
      if (error instanceof Prisma.PrismaClientKnownRequestError && ["P2002", "P2034"].includes(error.code)) {
        throw new ConflictException({ code: "APK_RELEASE_CONFLICT", message: "نسخه‌ای هم‌زمان منتشر شده است. فهرست را تازه کنید و دوباره تلاش کنید." });
      }
      throw error;
    }
  }
}

function serializeRelease(row: { id: bigint; versionName: string; versionCode: number; filePath: string; sha256: string; fileSizeBytes: bigint; releaseNotes: string | null; isCurrent: boolean; publishedAt: Date }) {
  return { id: row.id.toString(), versionName: row.versionName, versionCode: row.versionCode,
    downloadPath: row.filePath, sha256: row.sha256, fileSizeBytes: Number(row.fileSizeBytes),
    releaseNotes: row.releaseNotes, isCurrent: row.isCurrent, publishedAt: row.publishedAt.toISOString() };
}

// APK is a ZIP with an Android manifest and Dalvik code. Inspect its directory without expanding it.
async function validateApk(path: string) {
  const file = await open(path, "r");
  try {
    const stat = await file.stat();
    const tailLength = Math.min(stat.size, 65557);
    const tail = Buffer.alloc(tailLength);
    await file.read(tail, 0, tailLength, stat.size - tailLength);
    let end = -1;
    for (let i = tail.length - 22; i >= 0; i--) {
      if (tail.readUInt32LE(i) === 0x06054b50 && i + 22 + tail.readUInt16LE(i + 20) === tail.length) { end = i; break; }
    }
    if (end < 0 || tail.readUInt16LE(end + 4) !== 0 || tail.readUInt16LE(end + 6) !== 0) throw new Error("invalid zip");
    const size = tail.readUInt32LE(end + 12);
    const offset = tail.readUInt32LE(end + 16);
    if (size < 46 || size > 8 * 1024 * 1024 || offset + size > stat.size) throw new Error("invalid directory");
    const directory = Buffer.alloc(size);
    await file.read(directory, 0, size, offset);
    const names = new Set<string>();
    for (let position = 0; position + 46 <= directory.length;) {
      if (directory.readUInt32LE(position) !== 0x02014b50) throw new Error("invalid entry");
      const length = directory.readUInt16LE(position + 28);
      const extra = directory.readUInt16LE(position + 30);
      const comment = directory.readUInt16LE(position + 32);
      const next = position + 46 + length + extra + comment;
      if (next > directory.length) throw new Error("invalid bounds");
      names.add(directory.subarray(position + 46, position + 46 + length).toString("utf8"));
      position = next;
    }
    if (!names.has("AndroidManifest.xml") || !names.has("classes.dex")) throw new Error("not an apk");
  } catch {
    throw new BadRequestException({ code: "APK_INVALID", message: "این فایل یک بستهٔ APK معتبر نیست." });
  } finally { await file.close(); }
}
