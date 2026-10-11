import { Transform } from "class-transformer";
import { IsBoolean, IsEmail, IsOptional, IsString, MaxLength, MinLength } from "class-validator";

export class UpdateCustomerProfileDto {
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  fullName!: string;

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
