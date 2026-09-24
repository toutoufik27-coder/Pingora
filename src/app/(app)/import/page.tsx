import type { Metadata } from "next";
import { ConfirmButton } from "@/components/confirm-button";
import { ImportWizard } from "@/components/import-wizard";
import { Card, PageHeader, TableWrap, tableClass, tdClass, thClass } from "@/components/ui";
import { formatDate } from "@/lib/dates";
import { deleteImportAction } from "@/server/actions/imports";
import { getAppContext } from "@/server/context";
import { listImports } from "@/server/imports";

export const metadata: Metadata = { title: "Import from Airbnb" };

export default async function ImportPage() {
  const { db, workspace } = await getAppContext();
  const history = await listImports(db, workspace.id);

  return (
    <>
      <PageHeader
        title="Import from Airbnb"
        description="Upload the transaction history you export from Airbnb. Importing the same file twice is safe: rows already imported are skipped."
      />

      <div className="grid gap-6 lg:grid-cols-3">
        <Card title="Upload a CSV" className="lg:col-span-2">
          {/* Demo data is only offered to empty accounts so it never mixes with real bookings. */}
          <ImportWizard offerSample={history.length === 0} />
        </Card>

        <Card title="How to export from Airbnb">
          <ol className="list-decimal space-y-2 pl-5 text-sm text-slate-600">
            <li>
              Sign in to Airbnb and open <strong>Menu → Earnings</strong> (on some accounts, <strong>Today → Insights → Earnings</strong>).
            </li>
            <li>
              Choose <strong>Transaction history</strong>, then the <strong>Completed payouts</strong> tab.
            </li>
            <li>Filter the dates and listings you need, for example last month.</li>
            <li>
              Click <strong>Export CSV</strong> and upload the file here without opening it in Excel first.
            </li>
          </ol>
          <p className="mt-3 text-xs text-slate-500">
            Airbnb renames menus from time to time. If you can&apos;t find the export, look for the CSV download on your earnings page.
          </p>
        </Card>
      </div>

      <Card title="Import history" className="mt-6">
        {history.length === 0 ? (
          <p className="text-sm text-slate-500">No imports yet.</p>
        ) : (
          <TableWrap>
            <table className={tableClass}>
              <thead>
                <tr>
                  <th className={thClass}>File</th>
                  <th className={thClass}>Imported</th>
                  <th className={`${thClass} text-right`}>New rows</th>
                  <th className={`${thClass} text-right`}>Duplicates</th>
                  <th className={`${thClass} text-right`}>Ignored</th>
                  <th className={`${thClass} text-right`}>Problems</th>
                  <th className={thClass}>
                    <span className="sr-only">Actions</span>
                  </th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {history.map((record) => (
                  <tr key={record.id}>
                    <td className={`${tdClass} max-w-xs truncate font-medium text-slate-900`}>{record.fileName}</td>
                    <td className={tdClass}>{formatDate(record.createdAt.toISOString().slice(0, 10))}</td>
                    <td className={`${tdClass} tabular text-right`}>{record.remaining}</td>
                    <td className={`${tdClass} tabular text-right`}>{record.duplicateCount}</td>
                    <td className={`${tdClass} tabular text-right`}>{record.skippedCount}</td>
                    <td className={`${tdClass} tabular text-right`}>{record.errorCount}</td>
                    <td className={`${tdClass} text-right`}>
                      <form action={deleteImportAction.bind(null, record.id)}>
                        <ConfirmButton
                          label="Undo import"
                          confirmMessage={`Remove the ${record.remaining} transactions added by ${record.fileName}? Statements will change.`}
                        />
                      </form>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </TableWrap>
        )}
      </Card>
    </>
  );
}
