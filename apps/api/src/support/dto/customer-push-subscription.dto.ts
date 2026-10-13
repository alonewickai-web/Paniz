import { Type } from "class-transformer";
import { IsObject, IsString, IsUrl, Matches, MaxLength, ValidateNested } from "class-validator";

export class WebPushKeysDto {
  @IsString() @Matches(/^[A-Za-z0-9_-]{20,256}$/) p256dh!: string;
  @IsString() @Matches(/^[A-Za-z0-9_-]{8,128}$/) auth!: string;
}

export class CustomerPushSubscriptionDto {
  @IsString() @IsUrl({ protocols: ["https"], require_protocol: true }) @MaxLength(2048) endpoint!: string;
  @IsObject() @ValidateNested() @Type(() => WebPushKeysDto) keys!: WebPushKeysDto;
}

export class RemoveCustomerPushSubscriptionDto {
  @IsString() @IsUrl({ protocols: ["https"], require_protocol: true }) @MaxLength(2048) endpoint!: string;
}
