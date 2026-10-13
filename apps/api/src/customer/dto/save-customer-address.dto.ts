import { Transform, Type } from "class-transformer";
import { IsBoolean, IsNumber, IsOptional, IsString, Matches, Max, MaxLength, Min, MinLength } from "class-validator";
import { normalizeIranPhone } from "./phone.dto";

function normalizePostalCode(value: unknown): unknown {
  if (typeof value !== "string") return value;
  const persian = "۰۱۲۳۴۵۶۷۸۹";
  const arabic = "٠١٢٣٤٥٦٧٨٩";
  return value
    .replace(/[۰-۹]/g, (digit) => String(persian.indexOf(digit)))
    .replace(/[٠-٩]/g, (digit) => String(arabic.indexOf(digit)))
    .replace(/\D/g, "");
}

export class SaveCustomerAddressDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  title?: string;

  @IsString()
  @MinLength(2)
  @MaxLength(160)
  recipientName!: string;

  @Transform(({ value }) => typeof value === "string" ? normalizeIranPhone(value) : value)
  @IsString()
  @Matches(/^\+989\d{9}$/)
  recipientPhone!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  province!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(100)
  city!: string;

  @IsString()
  @MinLength(2)
  @MaxLength(200)
  street!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  alley?: string;

  @IsString()
  @MinLength(1)
  @MaxLength(40)
  plaqueNumber!: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  floor?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  unit?: string;

  @IsOptional()
  @Transform(({ value }) => typeof value === "string" && value.trim() ? normalizeIranPhone(value) : value)
  @IsString()
  @Matches(/^\+989\d{9}$/)
  backupPhone?: string;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  latitude!: number;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  longitude!: number;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  deliveryDetails?: string;

  @Transform(({ value }) => normalizePostalCode(value))
  @IsString()
  @Matches(/^\d{10}$/)
  postalCode!: string;

  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  isDefault?: boolean;
}
