import { IsOptional, IsString, Matches, MaxLength } from "class-validator";
import { QuoteCartDto } from "../../orders/dto/quote-cart.dto";

export class CreateCustomerOrderDto extends QuoteCartDto {
  @IsString()
  @Matches(/^\d{1,20}$/)
  addressId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  customerNote?: string;
}
