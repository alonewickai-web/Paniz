import { IsOptional, IsString, Length, Matches } from "class-validator";

export class AdminLoginDto {
  @IsOptional()
  @IsString()
  @Matches(/^(?:\+98|0098|0)?9[0-9۰-۹٠-٩]{9}$/)
  phone?: string;

  @IsOptional()
  @IsString()
  @Matches(/^[a-zA-Z0-9._-]{3,40}$/)
  username?: string;

  @IsString()
  @Length(1, 128)
  password!: string;
}
