import { Injectable, Logger, OnModuleDestroy } from "@nestjs/common";
import type { IncomingMessage, Server as HttpServer } from "node:http";
import type { Socket } from "node:net";
import { TLSSocket } from "node:tls";
import { WebSocket, WebSocketServer } from "ws";
import { PrismaService } from "../database/prisma.service";
import { AdminNotificationService } from "./admin-notification.service";

const SOCKET_PATH = "/api/v1/admin/notifications/socket";
const OPEN = WebSocket.OPEN;

type SocketIdentity = { adminId: bigint; deviceId: bigint; sessionId: bigint; alive: boolean };

@Injectable()
export class AdminNotificationGateway implements OnModuleDestroy {
  private readonly logger = new Logger(AdminNotificationGateway.name);
  private readonly sockets = new Map<WebSocket, SocketIdentity>();
  private webSocketServer?: WebSocketServer;
  private lastNotificationId = 0n;
  private pollTimer?: NodeJS.Timeout;
  private heartbeatTimer?: NodeJS.Timeout;
  private polling = false;

  constructor(private readonly prisma: PrismaService, private readonly notifications: AdminNotificationService) {}

  async attach(server: HttpServer) {
    if (this.webSocketServer) return;
    const last = await this.prisma.adminNotification.findFirst({ orderBy: { id: "desc" }, select: { id: true } });
    this.lastNotificationId = last?.id ?? 0n;
    this.webSocketServer = new WebSocketServer({ noServer: true, maxPayload: 2048, perMessageDeflate: false });
    server.on("upgrade", this.handleUpgrade);
    this.pollTimer = setInterval(() => void this.pollNotifications(), 1000);
    this.heartbeatTimer = setInterval(() => void this.heartbeat(), 25_000);
    this.pollTimer.unref();
    this.heartbeatTimer.unref();
  }

  private readonly handleUpgrade = (request: IncomingMessage, socket: Socket, head: Buffer) => {
    let pathname: string;
    try { pathname = new URL(request.url ?? "/", "http://localhost").pathname; }
    catch { return; }
    if (pathname !== SOCKET_PATH) return;
    void this.authorizeUpgrade(request, socket, head);
  };

  private async authorizeUpgrade(request: IncomingMessage, socket: Socket, head: Buffer) {
    const reject = (status: number, message: string) => {
      if (!socket.destroyed) socket.end(`HTTP/1.1 ${status} ${status === 401 ? "Unauthorized" : "Forbidden"}\r\nConnection: close\r\nContent-Length: ${Buffer.byteLength(message)}\r\n\r\n${message}`);
    };
    try {
      if (process.env.NODE_ENV === "production" && request.headers["x-forwarded-proto"] !== "https" && !(request.socket instanceof TLSSocket)) {
        reject(403, "Secure WebSocket required");
        return;
      }
      const [scheme, token, extra] = (request.headers.authorization ?? "").split(" ");
      if (scheme?.toLowerCase() !== "bearer" || !token || extra) { reject(401, "Unauthorized"); return; }
      const identity = await this.notifications.consumeSocketTicket(token);
      if (!identity || !this.webSocketServer || socket.destroyed) { reject(401, "Unauthorized"); return; }
      this.webSocketServer.handleUpgrade(request, socket, head, (webSocket) => {
        this.sockets.set(webSocket, { ...identity, alive: true });
        webSocket.on("pong", () => { const current = this.sockets.get(webSocket); if (current) current.alive = true; });
        webSocket.on("close", () => this.sockets.delete(webSocket));
        webSocket.on("error", () => this.sockets.delete(webSocket));
        webSocket.send(JSON.stringify({ type: "connected" }));
        void this.prisma.adminNotificationDevice.updateMany({ where: { id: identity.deviceId, revokedAt: null }, data: { lastSeenAt: new Date() } });
      });
    } catch (error) {
      this.logger.warn(`Notification WebSocket handshake rejected: ${error instanceof Error ? error.name : "unknown error"}`);
      reject(401, "Unauthorized");
    }
  }

  private async pollNotifications() {
    if (this.polling || !this.webSocketServer) return;
    this.polling = true;
    try {
      const rows = await this.prisma.adminNotification.findMany({
        where: { id: { gt: this.lastNotificationId } }, orderBy: { id: "asc" }, take: 500,
        select: { id: true, adminId: true, createdAt: true },
      });
      for (const row of rows) {
        this.lastNotificationId = row.id;
        const payload = JSON.stringify({ type: "notification_available", id: row.id.toString(), createdAt: row.createdAt.toISOString() });
        for (const [client, identity] of this.sockets) {
          if (identity.adminId === row.adminId && client.readyState === OPEN) client.send(payload);
        }
      }
    } catch (error) {
      this.logger.error("Notification event polling failed", error instanceof Error ? error.stack : undefined);
    } finally {
      this.polling = false;
    }
  }

  private async heartbeat() {
    const active = [...this.sockets.entries()];
    if (!active.length) return;
    const ids = active.map(([, identity]) => identity.deviceId);
    const now = new Date();
    try {
      const validDevices = await this.prisma.adminNotificationDevice.findMany({
        where: {
          id: { in: ids }, revokedAt: null,
          session: { is: { revokedAt: null, expiresAt: { gt: now } } },
          admin: { is: { isActive: true, notificationPreferences: { is: { backgroundMonitoringEnabled: true } } } },
        }, select: { id: true, sessionId: true },
      });
      const validSessions = new Set(validDevices.map((device) => `${device.id}:${device.sessionId}`));
      for (const [client, identity] of active) {
        if (!validSessions.has(`${identity.deviceId}:${identity.sessionId}`)) {
          client.close(1008, "session expired or monitoring disabled");
          this.sockets.delete(client);
        } else if (!identity.alive) {
          client.terminate();
          this.sockets.delete(client);
        } else if (client.readyState === OPEN) {
          identity.alive = false;
          client.ping();
        }
      }
      await this.prisma.adminNotificationDevice.updateMany({ where: { id: { in: validDevices.map((device) => device.id) }, revokedAt: null }, data: { lastSeenAt: now } });
    } catch (error) {
      this.logger.warn(`Notification connection heartbeat check failed: ${error instanceof Error ? error.name : "unknown error"}`);
      for (const [client, identity] of active) if (client.readyState === OPEN) { identity.alive = false; client.ping(); }
    }
  }

  onModuleDestroy() {
    if (this.pollTimer) clearInterval(this.pollTimer);
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer);
    for (const [client] of this.sockets) client.close(1001, "server stopping");
    this.sockets.clear();
    this.webSocketServer?.close();
  }
}
