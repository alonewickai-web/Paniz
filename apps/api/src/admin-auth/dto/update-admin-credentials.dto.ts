import { IsOptional, IsString, Length, Matches } from "class-validator";

export class UpdateAdminCredentialsDto {
  @IsString()
  @Length(1, 128)
  currentPassword!: string;

  @IsOptional()
  @IsString()
  @Matches(/^[a-zA-Z0-9._-]{3,40}$/)
  username?: string;

  @IsOptional()
  @IsString()
  @Length(12, 128)
  newPassword?: string;
}
