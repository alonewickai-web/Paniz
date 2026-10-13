import { IsBoolean, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from "class-validator";
import { Type } from "class-transformer";

export class UpdateAdminProductImageDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Matches(/^(?:\/(?!\/)|https:\/\/)/)
  imagePath?: string;

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
