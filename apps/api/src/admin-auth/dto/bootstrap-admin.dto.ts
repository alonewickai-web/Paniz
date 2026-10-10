import { IsString, Length, Matches, MaxLength } from "class-validator";

export class BootstrapAdminDto {
  @IsString()
  @Length(32, 256)
  setupKey!: string;

  @IsString()
  @MaxLength(160)
  fullName!: string;

  @IsString()
  @Matches(/^[a-zA-Z0-9._-]{3,40}$/)
  username!: string;

  @IsString()
  @Matches(/^(?:\+98|0098|0)?9[0-9۰-۹٠-٩]{9}$/)
  phone!: string;

  @IsString()
  @Length(12, 128)
  password!: string;
}
