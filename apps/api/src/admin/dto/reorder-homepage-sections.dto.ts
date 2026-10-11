import { ArrayNotEmpty, ArrayUnique, IsArray, IsString } from "class-validator";

export class ReorderHomepageSectionsDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayUnique()
  @IsString({ each: true })
  sectionKeys!: string[];
}
