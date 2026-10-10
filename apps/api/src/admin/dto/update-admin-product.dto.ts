import { IsIn, IsOptional, IsString, Matches, MaxLength } from "class-validator";

export class UpdateAdminProductDto {
  @IsOptional()
  @IsString()
  @MaxLength(220)
  name?: string;

  @IsOptional()
  @IsString()
  @MaxLength(240)
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
  slug?: string;

  @IsOptional()
  @IsString()
  @Matches(/^\d{1,20}$/)
  categoryId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  shortDescription?: string;

  @IsOptional()
  @IsString()
  @MaxLength(16_000)
  description?: string;

  @IsOptional()
  @IsString()
  @MaxLength(220)
  material?: string;

  @IsOptional()
  @IsString()
  @MaxLength(8_000)
  careInstructions?: string;

  @IsOptional()
  @IsIn(["draft", "published"])
  status?: "draft" | "published";
}
