import { join, resolve } from "node:path";
import { mkdirSync } from "node:fs";

export function uploadRoot(): string {
  const configured = process.env.UPLOADS_DIR?.trim();
  return resolve(configured || join(process.cwd(), "uploads"));
}

export function productImageRoot(): string {
  return join(uploadRoot(), "products");
}

export function supportImageRoot(): string {
  const path = join(uploadRoot(), "support");
  mkdirSync(path, { recursive: true });
  return path;
}

export function returnReceiptRoot(): string {
  const path = join(uploadRoot(), "returns");
  mkdirSync(path, { recursive: true });
  return path;
}
