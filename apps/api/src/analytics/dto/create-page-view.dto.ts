import { IsString, IsUUID, Matches, MaxLength } from "class-validator";

export class CreatePageViewDto {
  @IsUUID("4")
  visitorId!: string;

  @IsString()
  @MaxLength(500)
  @Matches(/^\/(?!\/)[^?#]*$/u)
  path!: string;
}
