import { Controller, Get } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import { HealthService } from "./health.service";

@ApiTags("سلامت سرویس")
@Controller("health")
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get("live")
  @ApiOperation({ summary: "بررسی زنده‌بودن API" })
  live(): { status: string; timestamp: string } {
    return this.healthService.live();
  }

  @Get("ready")
  @ApiOperation({ summary: "بررسی آمادگی API و اتصال دیتابیس" })
  ready(): Promise<{ status: string; database: string; timestamp: string }> {
    return this.healthService.ready();
  }
}
