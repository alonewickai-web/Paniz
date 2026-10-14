import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUrl,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from "class-validator";

export class AdminProductImageDto {
  @IsString()
  @MaxLength(500)
  @Matches(/^(?:\/(?!\/)|https:\/\/)/)
  imagePath!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  altText?: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  colorName?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1000)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isPrimary?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_048_575)
  fileSizeBytes?: number;
}

export class AdminProductVariantDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  @Matches(/^[A-Za-z0-9._-]+$/)
  sku?: string;

  @IsString()
  @MaxLength(80)
  colorName!: string;

  @IsOptional()
  @IsString()
  @Matches(/^#[0-9A-Fa-f]{6}$/)
  colorHex?: string;

  @IsString()
  @MaxLength(32)
  sizeLabel!: string;

  @IsString()
  @Matches(/^\d{1,15}$/)
  priceToman!: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{1,15}$/)
  compareAtPriceToman?: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(1_000_000)
  stockQuantity?: number;
}

export class CreateAdminProductDto {
  @IsString()
  @MaxLength(220)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  slug?: string;

  @IsString()
  @Matches(/^\d{1,20}$/)
  categoryId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  shortDescription?: string;

  @IsOptional()
  @IsString()
  @MaxLength(16_000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(220)
  material?: string;

  @IsOptional()
  @IsString()
  @MaxLength(8_000)
  careInstructions?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  seoTitle?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  seoDescription?: string;

  @IsOptional()
  @IsUrl({ protocols: ["https"], require_protocol: true })
  @MaxLength(500)
  seoCanonicalUrl?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{1,15}$/)
  purchaseCostToman?: string;

  @IsIn(["draft", "published"])
  status: "draft" | "published" = "draft";

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(1000)
  @ValidateNested({ each: true })
  @Type(() => AdminProductImageDto)
  images!: AdminProductImageDto[];

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(100)
  @ValidateNested({ each: true })
  @Type(() => AdminProductVariantDto)
  variants!: AdminProductVariantDto[];
}
