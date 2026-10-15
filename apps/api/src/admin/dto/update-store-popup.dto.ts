import { IsBoolean, IsOptional, IsString, Matches, MaxLength } from "class-validator";

export class UpdateStorePopupDto {
  @IsBoolean()
  enabled!: boolean;

  @IsOptional()
  @IsString()
  @Matches(/^\/uploads\/products\/[A-Za-z0-9_-]+\.(?:jpe?g|png|webp)$/i)
  imagePath?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  linkUrl?: string | null;
}
