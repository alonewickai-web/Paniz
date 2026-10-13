import { Type } from "class-transformer";
import { IsInt, IsOptional, IsString, Matches, Max, MaxLength, Min } from "class-validator";

export class PublishAdminAppDto {
  @IsString()
  @MaxLength(40)
  @Matches(/^\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9.-]+)?$/)
  versionName!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2147483647)
  versionCode!: number;

  @IsOptional()
  @IsString()
  @MaxLength(5000)
  releaseNotes?: string;
}
