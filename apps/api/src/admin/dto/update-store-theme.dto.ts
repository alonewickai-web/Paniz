import { IsIn, IsString } from "class-validator";

export const STORE_THEMES = ["rose", "mint", "peach", "lilac", "coral", "dark"] as const;

export class UpdateStoreThemeDto {
  @IsString()
  @IsIn(STORE_THEMES)
  theme!: (typeof STORE_THEMES)[number];
}
