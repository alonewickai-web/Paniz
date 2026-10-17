import { Transform, Type } from "class-transformer";
import { IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min, MinLength } from "class-validator";

export class CreateProductReviewDto {
  @Transform(({ value }) => typeof value === "string" ? value.trim() : value)
  @IsString()
  @Matches(/^\d{1,20}$/)
  orderItemId!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(5)
  rating!: number;

  @IsOptional()
  @Transform(({ value }) => typeof value === "string" ? value.trim() : value)
  @IsString()
  @MaxLength(160)
  title?: string;

  @IsOptional()
  @Transform(({ value }) => typeof value === "string" ? value.trim() : value)
  @IsString()
  @MinLength(5)
  @MaxLength(2000)
  body?: string;
}
