import { ArrayMaxSize, ArrayMinSize, IsArray, IsOptional, IsString, MaxLength, Matches, ValidateNested } from "class-validator";
import { Type } from "class-transformer";
import { CartItemDto } from "./cart-item.dto";

export class QuoteCartDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => CartItemDto)
  items!: CartItemDto[];

  @IsOptional()
  @IsString()
  @MaxLength(64)
  @Matches(/^[a-zA-Z0-9_-]*$/)
  couponCode?: string;
}
