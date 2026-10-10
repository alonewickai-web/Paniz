import { IsIn, IsOptional, IsString, MaxLength } from "class-validator";
import { ADMIN_ORDER_STATUSES } from "./list-admin-orders.query";

export class UpdateAdminOrderDto {
  @IsIn(ADMIN_ORDER_STATUSES)
  status!: (typeof ADMIN_ORDER_STATUSES)[number];

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  trackingCode?: string;
}
