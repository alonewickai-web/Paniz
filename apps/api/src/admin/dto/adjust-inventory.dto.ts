import { IsInt, IsString, Max, MaxLength, Min } from "class-validator";

export class AdjustInventoryDto {
  @IsInt()
  @Min(-100_000)
  @Max(100_000)
  delta!: number;

  @IsString()
  @MaxLength(500)
  note!: string;
}
