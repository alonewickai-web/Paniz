import { IsInt, IsString, Max, MaxLength, Min } from "class-validator";

export class AdjustInventoryDto {
  @IsInt()
  @Min(-2_147_483_647)
  @Max(2_147_483_647)
  delta!: number;

  @IsString()
  @MaxLength(500)
  note!: string;
}
