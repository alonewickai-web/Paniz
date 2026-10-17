import { ArrayMaxSize, ArrayUnique, IsArray, IsString, IsUUID, Matches, MaxLength } from "class-validator";

export class SyncPublicFavoritesDto {
  @IsUUID("4")
  visitorId!: string;

  @IsArray()
  @ArrayMaxSize(500)
  @ArrayUnique()
  @IsString({ each: true })
  @MaxLength(20, { each: true })
  @Matches(/^\d{1,20}$/, { each: true })
  productIds!: string[];
}
