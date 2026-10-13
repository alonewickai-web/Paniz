import { IsString, Matches, MaxLength, MinLength } from "class-validator";

export class CreateReturnDto {
  @IsString() @MinLength(3) @MaxLength(2000) reason!: string;
  @IsString() @Matches(/^IR\d{24}$/i, { message: "شماره شبا باید با IR و ۲۴ رقم وارد شود." }) iban!: string;
  @IsString() @Matches(/^\d{16}$/, { message: "شماره کارت باید ۱۶ رقم باشد." }) cardNumber!: string;
}

export class UpdateReturnDto {
  @IsString() @Matches(/^(requested|approved|received|refunded|rejected)$/) status!: string;
  @IsString() @MaxLength(2000) adminNote!: string;
}
