import { IsNumber, IsOptional, IsString, MaxLength } from "class-validator";

export class UpdateStoreAboutDto {
  @IsOptional() @IsString() @MaxLength(120) introTitle?: string;
  @IsOptional() @IsString() @MaxLength(2000) introDescription?: string;
  @IsString() @MaxLength(500) address!: string;
  @IsString() @MaxLength(40) phone!: string;
  @IsString() @MaxLength(500) rubikaUrl!: string;
  @IsString() @MaxLength(500) instagramUrl!: string;
  @IsString() @MaxLength(500) physicalAddress!: string;
  @IsString() @MaxLength(500) mapUrl!: string;
  @IsOptional() @IsNumber() latitude?: number | null;
  @IsOptional() @IsNumber() longitude?: number | null;
}
