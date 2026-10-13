import { IsOptional, IsString, Matches, MaxLength, ValidateIf } from "class-validator";

export class UpdateStoreLogoDto {
  @ValidateIf((_object, value) => value !== null)
  @IsOptional()
  @IsString()
  @MaxLength(500)
  @Matches(/^\/uploads\/products\/[a-f0-9-]+\.(jpg|png|webp)$/i)
  logoPath?: string | null;
}
