import { IsString, MaxLength } from "class-validator";

export class UpdateStoreAboutDto {
  @IsString() @MaxLength(500) address!: string;
  @IsString() @MaxLength(40) phone!: string;
  @IsString() @MaxLength(500) rubikaUrl!: string;
  @IsString() @MaxLength(500) instagramUrl!: string;
  @IsString() @MaxLength(500) physicalAddress!: string;
  @IsString() @MaxLength(500) mapUrl!: string;
}
