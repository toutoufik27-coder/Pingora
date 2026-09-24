import type { NextRequest } from "next/server";
import { APP_NAME } from "@/lib/brand";
import { monthPeriod, todayIso } from "@/lib/dates";
import { renderStatementPdf } from "@/lib/pdf/statement-pdf";
import { monthParam } from "@/lib/search-params";
import { getAppContext } from "@/server/context";
import { loadOwnerStatement } from "@/server/statements";

function slugify(value: string): string {
  return (
    value
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "") || "owner"
  );
}

export async function GET(request: NextRequest, context: RouteContext<"/statements/[ownerId]/pdf">) {
  const { ownerId } = await context.params;
  const month = monthParam(Object.fromEntries(request.nextUrl.searchParams));
  const { db, workspace } = await getAppContext();
  const statement = await loadOwnerStatement(db, workspace, ownerId, monthPeriod(month));
  if (!statement) return new Response("Owner not found", { status: 404 });

  const pdf = await renderStatementPdf(statement, { businessName: workspace.name, generatedOn: todayIso(), appName: APP_NAME });
  return new Response(new Blob([pdf.slice()], { type: "application/pdf" }), {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${slugify(statement.owner.name)}-statement-${month}.pdf"`,
      "Cache-Control": "private, no-store",
    },
  });
}
