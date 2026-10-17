import { Type } from "class-transformer";
import { ArrayMaxSize, ArrayMinSize, IsArray, IsString, MaxLength, ValidateNested } from "class-validator";

export class StoreReturnsPolicySectionDto {
  @IsString()
  @MaxLength(120)
  heading!: string;

  @IsString()
  @MaxLength(3000)
  body!: string;
}

export class UpdateStoreReturnsPolicyDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(20)
  @ValidateNested({ each: true })
  @Type(() => StoreReturnsPolicySectionDto)
  sections!: StoreReturnsPolicySectionDto[];
}
