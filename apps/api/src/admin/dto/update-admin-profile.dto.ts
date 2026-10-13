import { IsOptional, IsString, MaxLength, MinLength } from "class-validator";

export class UpdateAdminProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(160)
  fullName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(24)
  phone?: string | null;

}
