import { IsString, Matches } from "class-validator";
import { PhoneDto } from "./phone.dto";

export class VerifyPhoneCodeDto extends PhoneDto {
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}
