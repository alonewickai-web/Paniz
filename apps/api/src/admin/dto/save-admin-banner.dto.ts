import { IsBoolean, IsDateString, IsInt, IsOptional, IsString, Max, MaxLength, Min } from "class-validator";

export class SaveAdminBannerDto {
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
