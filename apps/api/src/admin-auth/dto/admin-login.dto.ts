import { IsString, Length, Matches } from "class-validator";

export class AdminLoginDto {
  @IsString()
  @Length(3, 40)
  @Matches(/^[a-zA-Z0-9._-]{3,40}$/)
  username!: string;

  @IsString()
  @Length(1, 128)
  password!: string;
}
