import { IsString, Matches, MaxLength, MinLength } from "class-validator";

export class CreateContactMessageDto {
  @IsString()
  @MinLength(2)
  @MaxLength(100)
  name!: string;

  @IsString()
  @Matches(/^(?:\+98|0098|0)?9\d{9}$/)
  phone!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(1500)
  message!: string;
}
