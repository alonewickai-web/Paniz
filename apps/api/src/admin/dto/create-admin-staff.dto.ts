import { ArrayUnique, IsArray, IsOptional, IsString, Matches, MaxLength, MinLength } from "class-validator";

export class CreateAdminStaffDto {
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  fullName!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(80)
  @Matches(/^[a-zA-Z0-9._-]+$/)
  username!: string;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  phone?: string | null;

  @IsArray()
  @ArrayUnique()
  @IsString({ each: true })
  permissions!: string[];
}
