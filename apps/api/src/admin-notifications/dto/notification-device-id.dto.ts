import { IsUUID } from "class-validator";

export class NotificationDeviceIdDto {
  @IsUUID("4") deviceId!: string;
}
