import { Body, Controller, Get, Param, Post, Req, UseGuards } from "@nestjs/common";
import { ApiBearerAuth, ApiOperation, ApiTags } from "@nestjs/swagger";
import { AdminRequest, AdminSessionGuard } from "../admin-auth/admin-session.guard";
import { AdminChatService } from "./admin-chat.service";

@ApiTags("گفت‌وگوی مدیران")
@ApiBearerAuth("admin-session")
@UseGuards(AdminSessionGuard)
@Controller("admin/chat")
export class AdminChatController {
  constructor(private readonly chat: AdminChatService) {}

  @Get("contacts")
  @ApiOperation({ summary: "فهرست مخاطبان گفت‌وگوی مدیران" })
  contacts(@Req() request: AdminRequest) { return this.chat.contacts(request.admin!); }

  @Get("messages/:contactId")
  @ApiOperation({ summary: "گرفتن پیام‌های گفت‌وگوی انتخاب‌شده" })
  messages(@Req() request: AdminRequest, @Param("contactId") id: string) { return this.chat.messages(request.admin!, id); }

  @Post("messages")
  @ApiOperation({ summary: "ارسال پیام مدیر یا پخش پیام متنی سوپرادمین" })
  send(@Req() request: AdminRequest, @Body() body: { recipientAdminId?: string; body: string; broadcast?: boolean }) {
    return this.chat.send(request.admin!, body);
  }
}
