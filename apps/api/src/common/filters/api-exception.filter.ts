import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
} from "@nestjs/common";
import { randomUUID } from "node:crypto";
import type { Request, Response } from "express";

@Catch()
export class ApiExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost): void {
    const http = host.switchToHttp();
    const request = http.getRequest<Request>();
    const response = http.getResponse<Response>();
    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;
    const exceptionResponse = exception instanceof HttpException ? exception.getResponse() : undefined;
    const responseObject = typeof exceptionResponse === "object" && exceptionResponse !== null
      ? (exceptionResponse as Record<string, unknown>)
      : undefined;
    const rawMessage = responseObject?.message ?? (typeof exceptionResponse === "string" ? exceptionResponse : undefined);
    const message = Array.isArray(rawMessage)
      ? rawMessage.map(String)
      : typeof rawMessage === "string"
        ? rawMessage
        : status === HttpStatus.INTERNAL_SERVER_ERROR
          ? "خطای داخلی سرور"
          : "درخواست قابل پردازش نیست";

    response.status(status).json({
      error: {
        statusCode: status,
        code: typeof responseObject?.code === "string" ? responseObject.code : `HTTP_${status}`,
        message,
        requestId: randomUUID(),
        path: request.path,
      },
    });
  }
}
