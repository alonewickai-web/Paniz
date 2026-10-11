import { join, resolve } from "node:path";

export function uploadRoot(): string {
  const configured = process.env.UPLOADS_DIR?.trim();
  return resolve(configured || join(process.cwd(), "uploads"));
}

export function productImageRoot(): string {
  return join(uploadRoot(), "products");
}
