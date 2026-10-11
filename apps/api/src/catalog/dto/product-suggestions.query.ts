import { IsString, MaxLength } from "class-validator";

export class ProductSuggestionsQuery {
  @IsString()
  @MaxLength(100)
  q!: string;
}
