import { IsBoolean, IsOptional, IsString, Matches, MaxLength } from "class-validator";

export class SaveShippingSettingsDto {
  @IsOptional() @IsString() @MaxLength(120) name = "ارسال پستی";
  @IsString() @Matches(/^\d{1,14}$/) baseCostToman!: string;
  @IsBoolean() freeShippingEnabled!: boolean;
  @IsOptional() @IsString() @Matches(/^\d{1,14}$/) freeOverToman?: string;
  @IsBoolean() alwaysFree = false;
}
