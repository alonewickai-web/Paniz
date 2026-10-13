import { IsBoolean, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min, ValidateIf } from "class-validator";
import { Type } from "class-transformer";

export class UpdateAdminVariantDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  colorName?: string;

  @IsOptional()
  @IsString()
  @Matches(/^#[0-9A-Fa-f]{6}$/)
  colorHex?: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  sizeLabel?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{1,15}$/)
  priceToman?: string;

  @ValidateIf((_object, value) => value !== undefined && value !== null)
  @IsString()
  @Matches(/^\d{1,15}$/)
  compareAtPriceToman?: string | null;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  lowStockThreshold?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1000)
  colorSortOrder?: number;
}
