import type { NextRequest } from "next/server";
import { monthPeriod } from "@/lib/dates";
import { monthParam } from "@/lib/search-params";
import { getAppContext } from "@/server/context";
import { statementFileName, statementPdf } from "@/server/statement-delivery";
import { loadOwnerStatement } from "@/server/statements";

export async function GET(request: NextRequest, context: RouteContext<"/statements/[ownerId]/pdf">) {
  const { ownerId } = await context.params;
  const month = monthParam(Object.fromEntries(request.nextUrl.searchParams));
  const { db, workspace } = await getAppContext();
  const statement = await loadOwnerStatement(db, workspace, ownerId, monthPeriod(month));
  if (!statement) return new Response("Owner not found", { status: 404 });

  const pdf = await statementPdf(statement, workspace.name);
  return new Response(new Blob([pdf.slice()], { type: "application/pdf" }), {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${statementFileName(statement, "pdf")}"`,
      "Cache-Control": "private, no-store",
    },
  });
}
