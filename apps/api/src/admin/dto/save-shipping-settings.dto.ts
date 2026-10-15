import { IsBoolean, IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from "class-validator";

export class SaveShippingSettingsDto {
  @IsOptional() @IsString() @MaxLength(120) name = "ارسال پستی";
  @IsOptional() @IsString() @MaxLength(500) description?: string | null;
  @IsOptional() @IsInt() @Min(1) @Max(255) estimatedDaysMin?: number | null;
  @IsOptional() @IsInt() @Min(1) @Max(255) estimatedDaysMax?: number | null;
  @IsString() @Matches(/^\d{1,14}$/) baseCostToman!: string;
  @IsBoolean() freeShippingEnabled!: boolean;
  @IsOptional() @IsString() @Matches(/^\d{1,14}$/) freeOverToman?: string;
  @IsBoolean() alwaysFree = false;
}
