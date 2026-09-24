import type { NextRequest } from "next/server";
import { isValidMonth, monthPeriod } from "@/lib/dates";
import { workspaceHasAccess } from "@/server/context";
import { getDb } from "@/server/db/client";
import { getOwnerByPortalToken } from "@/server/owners";
import { statementFileName, statementPdf } from "@/server/statement-delivery";
import { sentPeriodsForOwner } from "@/server/statement-sends";
import { loadOwnerStatement } from "@/server/statements";
import { getWorkspace } from "@/server/workspace";

/** PDF of a statement that was sent to the owner, through their portal link. */
export async function GET(request: NextRequest, context: RouteContext<"/o/[token]/pdf">) {
  const { token } = await context.params;
  const month = request.nextUrl.searchParams.get("month");
  const db = await getDb();
  const owner = await getOwnerByPortalToken(db, token);
  const workspace = owner ? await getWorkspace(db, owner.workspaceId) : null;
  if (!owner || !workspace || !workspaceHasAccess(workspace) || !isValidMonth(month)) return new Response("Not found", { status: 404 });
  if (!(await sentPeriodsForOwner(db, owner.id)).includes(month)) return new Response("Not found", { status: 404 });

  const statement = await loadOwnerStatement(db, workspace, owner.id, monthPeriod(month));
  if (!statement) return new Response("Not found", { status: 404 });
  const pdf = await statementPdf(statement, workspace.name);
  return new Response(new Blob([pdf.slice()], { type: "application/pdf" }), {
    headers: {
      "Content-Type": "application/pdf",
      "Content-Disposition": `attachment; filename="${statementFileName(statement, "pdf")}"`,
      "Cache-Control": "private, no-store",
    },
  });
}
