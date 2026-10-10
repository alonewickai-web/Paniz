import { Transform } from "class-transformer";
import { IsString, Matches, MaxLength } from "class-validator";

function normalizeDigits(value: unknown): unknown {
  if (typeof value !== "string") return value;
  const digits = "۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩";
  return value.replace(/[۰-۹٠-٩]/g, (digit) => String(digits.indexOf(digit) % 10)).trim();
}

export class TrackOrderDto {
  @IsString()
  @Matches(/^PS-[A-Z0-9-]{8,32}$/i)
  orderNumber!: string;

  @Transform(({ value }) => normalizeDigits(value))
  @IsString()
  @Matches(/^(?:\+98|0098|0)?9\d{9}$/)
  phone!: string;
}
