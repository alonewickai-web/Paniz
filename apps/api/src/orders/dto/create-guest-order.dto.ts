import { Transform } from "class-transformer";
import { IsOptional, IsString, Matches, MaxLength } from "class-validator";
import { QuoteCartDto } from "./quote-cart.dto";

function normalizeDigits(value: unknown): unknown {
  if (typeof value !== "string") return value;
  const digits = "۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩";
  return value.replace(/[۰-۹٠-٩]/g, (digit) => {
    const index = digits.indexOf(digit);
    return String(index % 10);
  }).trim();
}

export class CreateGuestOrderDto extends QuoteCartDto {
  @IsString()
  @MaxLength(160)
  recipientName!: string;

  @Transform(({ value }) => normalizeDigits(value))
  @IsString()
  @Matches(/^(?:\+98|0098|0)?9\d{9}$/)
  recipientPhone!: string;

  @IsString()
  @MaxLength(100)
  province!: string;

  @IsString()
  @MaxLength(100)
  city!: string;

  @IsString()
  @MaxLength(500)
  addressLine!: string;

  @Transform(({ value }) => normalizeDigits(value))
  @IsString()
  @Matches(/^\d{10}$/)
  postalCode!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  customerNote?: string;
}
