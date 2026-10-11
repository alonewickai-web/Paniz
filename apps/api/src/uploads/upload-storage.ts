import { join, resolve } from "node:path";

export function uploadRoot(): string {
  const configured = process.env.UPLOADS_DIR?.trim();
  const railwayVolume = process.env.RAILWAY_VOLUME_MOUNT_PATH?.trim();
  return resolve(configured || railwayVolume || join(process.cwd(), "uploads"));
}

export function productImageRoot(): string {
  return join(uploadRoot(), "products");
}
