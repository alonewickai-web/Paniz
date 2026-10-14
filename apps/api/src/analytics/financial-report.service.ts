import { BadRequestException, Injectable } from "@nestjs/common";
import { toJalaali } from "jalaali-js";
import { PrismaService } from "../database/prisma.service";

const IRAN_OFFSET_MS = 210 * 60_000;
type DayRow = { day: string; salesToman: bigint; orderCount: bigint };
type CostRow = { day: string; productCostToman: bigint };

@Injectable()
export class FinancialReportService {
  constructor(private readonly prisma: PrismaService) {}

  async report(rangeText: string | undefined, fromText?: string, toText?: string) {
    const range = rangeText ?? "7";
    const custom = Boolean(fromText || toText);
    if (custom && (!fromText || !toText)) throw new BadRequestException({ code: "FINANCE_DATE_RANGE_REQUIRED", message: "تاریخ شروع و پایان را هر دو انتخاب کن." });
    if (!custom && !["today", "7", "10", "30", "month"].includes(range)) throw new BadRequestException({ code: "INVALID_FINANCE_RANGE", message: "بازهٔ گزارش مالی معتبر نیست." });
    const nowIran = new Date(Date.now() + IRAN_OFFSET_MS);
    const todayIran = new Date(Date.UTC(nowIran.getUTCFullYear(), nowIran.getUTCMonth(), nowIran.getUTCDate()));
    const startIran = custom ? parseDay(fromText!) : range === "month"
      ? new Date(Date.UTC(todayIran.getUTCFullYear(), todayIran.getUTCMonth(), 1))
      : range === "today" ? todayIran : new Date(todayIran.getTime() - (Number(range) - 1) * 86_400_000);
    const lastIran = custom ? parseDay(toText!) : todayIran;
    if (startIran > lastIran) throw new BadRequestException({ code: "INVALID_FINANCE_DATE_RANGE", message: "تاریخ شروع نمی‌تواند بعد از تاریخ پایان باشد." });
    const days = Math.floor((lastIran.getTime() - startIran.getTime()) / 86_400_000) + 1;
    if (days > 3660) throw new BadRequestException({ code: "FINANCE_RANGE_TOO_LARGE", message: "بازهٔ گزارش حداکثر ده سال است." });
    const startUtc = new Date(startIran.getTime() - IRAN_OFFSET_MS);
    const endUtc = new Date(lastIran.getTime() + 86_400_000 - IRAN_OFFSET_MS);
    const [sales, costs] = await Promise.all([
      this.prisma.$queryRaw<DayRow[]>`
        SELECT DATE_FORMAT(DATE_ADD(placed_at, INTERVAL 210 MINUTE), '%Y-%m-%d') AS day,
          CAST(COALESCE(SUM(total_toman), 0) AS UNSIGNED) AS salesToman,
          CAST(COUNT(*) AS UNSIGNED) AS orderCount
        FROM orders
        WHERE payment_status = 'paid' AND placed_at >= ${startUtc} AND placed_at < ${endUtc}
        GROUP BY DATE_FORMAT(DATE_ADD(placed_at, INTERVAL 210 MINUTE), '%Y-%m-%d')
        ORDER BY day ASC
      `,
      this.prisma.$queryRaw<CostRow[]>`
        SELECT DATE_FORMAT(DATE_ADD(o.placed_at, INTERVAL 210 MINUTE), '%Y-%m-%d') AS day,
          CAST(COALESCE(SUM(i.purchase_cost_toman * i.quantity), 0) AS UNSIGNED) AS productCostToman
        FROM orders o JOIN order_items i ON i.order_id = o.id
        WHERE o.payment_status = 'paid' AND o.placed_at >= ${startUtc} AND o.placed_at < ${endUtc}
        GROUP BY DATE_FORMAT(DATE_ADD(o.placed_at, INTERVAL 210 MINUTE), '%Y-%m-%d')
        ORDER BY day ASC
      `,
    ]);
    const salesByDay = new Map(sales.map((row) => [row.day, row]));
    const costsByDay = new Map(costs.map((row) => [row.day, row.productCostToman]));
    const daily = Array.from({ length: days }, (_, index) => {
      const date = new Date(startIran.getTime() + index * 86_400_000);
      const iso = `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(date.getUTCDate())}`;
      const row = salesByDay.get(iso);
      const revenueToman = row?.salesToman ?? 0n;
      const productCostToman = costsByDay.get(iso) ?? 0n;
      return {
        date: iso,
        dateJalali: jalaliDate(date.getUTCFullYear(), date.getUTCMonth() + 1, date.getUTCDate()),
        salesRial: safe(revenueToman * 10n),
        productCostRial: safe(productCostToman * 10n),
        grossProfitRial: safe((revenueToman - productCostToman) * 10n),
        orderCount: safe(row?.orderCount ?? 0n),
      };
    });
    return { data: { range, currency: "IRR", daily, totals: daily.reduce((total, row) => ({
      salesRial: total.salesRial + row.salesRial,
      productCostRial: total.productCostRial + row.productCostRial,
      grossProfitRial: total.grossProfitRial + row.grossProfitRial,
      orderCount: total.orderCount + row.orderCount,
    }), { salesRial: 0, productCostRial: 0, grossProfitRial: 0, orderCount: 0 }) } };
  }
}

function parseDay(value: string): Date {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (!match) throw new BadRequestException({ code: "INVALID_FINANCE_DATE", message: "تاریخ گزارش معتبر نیست." });
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])));
  if (date.toISOString().slice(0, 10) !== value) throw new BadRequestException({ code: "INVALID_FINANCE_DATE", message: "تاریخ گزارش معتبر نیست." });
  return date;
}

function jalaliDate(year: number, month: number, day: number) {
  const value = toJalaali(year, month, day);
  return `${value.jy}/${pad(value.jm)}/${pad(value.jd)}`;
}

function pad(value: number) { return String(value).padStart(2, "0"); }
function safe(value: bigint) {
  const number = Number(value);
  if (!Number.isSafeInteger(number)) throw new Error("Finance total exceeds JavaScript's safe integer range.");
  return number;
}
