import { Type } from "class-transformer";
import { ArrayMaxSize, ArrayMinSize, IsArray, IsString, MaxLength, ValidateNested } from "class-validator";

export class StoreFaqItemDto {
  @IsString()
  @MaxLength(240)
  question!: string;

  @IsString()
  @MaxLength(5000)
  answer!: string;
}

export class UpdateStoreFaqsDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(50)
  @ValidateNested({ each: true })
  @Type(() => StoreFaqItemDto)
  faqs!: StoreFaqItemDto[];
}
