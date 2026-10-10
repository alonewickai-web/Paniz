import { Transform } from "class-transformer";
import { IsString, Matches } from "class-validator";

export function toAsciiDigits(value: string): string {
  const persian = "۰۱۲۳۴۵۶۷۸۹";
  const arabic = "٠١٢٣٤٥٦٧٨٩";
  return value
    .replace(/[۰-۹]/g, (digit) => String(persian.indexOf(digit)))
    .replace(/[٠-٩]/g, (digit) => String(arabic.indexOf(digit)));
}

export function normalizeIranPhone(value: string): string {
  const digits = toAsciiDigits(value).replace(/\D/g, "");
  if (digits.startsWith("0098")) return `+${digits.slice(2)}`;
  if (digits.startsWith("98") && digits.length === 12) return `+${digits}`;
  if (digits.startsWith("0")) return `+98${digits.slice(1)}`;
  if (digits.startsWith("9") && digits.length === 10) return `+98${digits}`;
  return digits ? `+${digits}` : "";
}

export class PhoneDto {
  @Transform(({ value }) => typeof value === "string" ? normalizeIranPhone(value) : value)
  @IsString()
  @Matches(/^\+989\d{9}$/)
  phone!: string;
}
