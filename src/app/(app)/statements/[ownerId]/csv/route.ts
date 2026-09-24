import type { NextRequest } from "next/server";
import { monthPeriod } from "@/lib/dates";
import { monthParam } from "@/lib/search-params";
import { statementToCsv } from "@/lib/statement-csv";
import { getAppContext } from "@/server/context";
import { statementFileName } from "@/server/statement-delivery";
import { loadOwnerStatement } from "@/server/statements";

export async function GET(request: NextRequest, context: RouteContext<"/statements/[ownerId]/csv">) {
  const { ownerId } = await context.params;
  const month = monthParam(Object.fromEntries(request.nextUrl.searchParams));
  const { db, workspace } = await getAppContext();
  const statement = await loadOwnerStatement(db, workspace, ownerId, monthPeriod(month));
  if (!statement) return new Response("Owner not found", { status: 404 });

  return new Response(statementToCsv(statement), {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${statementFileName(statement, "csv")}"`,
      "Cache-Control": "private, no-store",
    },
  });
}
