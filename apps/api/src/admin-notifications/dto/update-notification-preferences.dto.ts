import { IsBoolean, IsOptional } from "class-validator";

export class UpdateNotificationPreferencesDto {
  @IsOptional() @IsBoolean() newOrdersEnabled?: boolean;
  @IsOptional() @IsBoolean() paymentsEnabled?: boolean;
  @IsOptional() @IsBoolean() lowStockEnabled?: boolean;
  @IsOptional() @IsBoolean() securityAlertsEnabled?: boolean;
  @IsOptional() @IsBoolean() serverAlertsEnabled?: boolean;
  @IsOptional() @IsBoolean() customerMessagesEnabled?: boolean;
  @IsOptional() @IsBoolean() adminMessagesEnabled?: boolean;
  @IsOptional() @IsBoolean() appUpdatesEnabled?: boolean;
  @IsOptional() @IsBoolean() soundEnabled?: boolean;
  @IsOptional() @IsBoolean() vibrationEnabled?: boolean;
  @IsOptional() @IsBoolean() backgroundMonitoringEnabled?: boolean;
}
