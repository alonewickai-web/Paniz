import { IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min } from "class-validator";
import { Type } from "class-transformer";

export const ADMIN_ORDER_STATUSES = [
  "pending_payment", "paid", "confirmed", "preparing", "shipped", "delivered", "cancelled", "expired", "returned",
] as const;

export class ListAdminOrdersQuery {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page = 1;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize = 20;

  @IsOptional()
  @IsIn(ADMIN_ORDER_STATUSES)
  status?: (typeof ADMIN_ORDER_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(40)
  q?: string;
}
