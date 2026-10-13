import { Transform } from "class-transformer";
import { IsBoolean, IsEmail, IsOptional, IsString, Matches, MaxLength, MinLength } from "class-validator";

export class UpdateCustomerProfileDto {
  @Transform(({ value }) => typeof value === "string" ? value.trim() : value)
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  fullName!: string;

  @IsOptional()
  @IsString()
  @Matches(/^1[34]\d{2}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/)
  birthDateJalali?: string | null;

  @IsOptional()
  @Transform(({ value }) => typeof value === "string" ? value.trim() || undefined : value)
  @IsEmail()
  @MaxLength(254)
  email?: string | null;

  @IsOptional()
  @IsBoolean()
  marketingOptIn?: boolean;

  @IsOptional()
  @IsBoolean()
  rubikaMarketingOptIn?: boolean;
}
