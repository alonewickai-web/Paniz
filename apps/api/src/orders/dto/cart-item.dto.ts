import { Type } from "class-transformer";
import { IsInt, IsString, Matches, Max, Min } from "class-validator";

export class CartItemDto {
  @IsString()
  @Matches(/^\d{1,20}$/)
  variantId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(10)
  quantity!: number;
}
