import { IsOptional, IsString, MaxLength, MinLength, Matches } from "class-validator";

export class CreateTicketDto {
  @IsString() @MinLength(3) @MaxLength(180) subject!: string;
  @IsString() @MinLength(2) @MaxLength(4000) message!: string;
  @IsOptional() @IsString() @Matches(/^\/uploads\/support\/[a-f0-9-]+\.(jpg|png|webp)$/i) imagePath?: string;
}

export class SupportMessageDto {
  @IsString() @MinLength(1) @MaxLength(4000) body!: string;
  @IsOptional() @IsString() @Matches(/^\/uploads\/support\/[a-f0-9-]+\.(jpg|png|webp)$/i) imagePath?: string;
}
