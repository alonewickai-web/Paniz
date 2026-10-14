import { IsBoolean, IsDateString, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from "class-validator";

export class SaveAdminBannerDto {
  @IsOptional()
  @IsString()
  @MaxLength(180)
  altText?: string;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  description?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  imagePath?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  targetUrl?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  eyebrowText?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  buttonLabel?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  buttonSideText?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  stickerLabel?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(180)
  stickerText?: string | null;

  @IsOptional()
  @IsString()
  @Matches(/^#[0-9a-fA-F]{6}$/)
  backgroundColor?: string | null;

  @IsOptional()
  @IsDateString()
  startsAt?: string | null;

  @IsOptional()
  @IsDateString()
  endsAt?: string | null;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100000)
  sortOrder?: number;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
