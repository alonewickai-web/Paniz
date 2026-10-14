import { IsOptional, IsString, IsUUID, MaxLength } from "class-validator";

export class RegisterNotificationDeviceDto {
  @IsUUID("4") deviceId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceName?: string;
}
