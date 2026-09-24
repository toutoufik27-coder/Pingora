import type { Metadata } from "next";
import Link from "next/link";
import { ActionForm } from "@/components/action-form";
import { ButtonLink, Card, Field, inputClass, PageHeader, TableWrap, tableClass, tdClass, thClass } from "@/components/ui";
import { defaultStatementMonth } from "@/lib/dates";
import { createOwnerAction } from "@/server/actions/owners";
import { getAppContext } from "@/server/context";
import { listOwners } from "@/server/owners";

export const metadata: Metadata = { title: "Owners" };

export default async function OwnersPage() {
  const { db, workspace } = await getAppContext();
  const owners = await listOwners(db, workspace.id);
  const month = defaultStatementMonth();

  return (
    <>
      <PageHeader title="Owners" description="The property owners you co-host for. Each owner gets one statement per month covering all of their properties." />

      <div className="grid gap-6 lg:grid-cols-3">
        <Card title="Add an owner">
          <ActionForm action={createOwnerAction} submitLabel="Add owner" pendingLabel="Adding…" className="space-y-4">
            <Field label="Name" htmlFor="name">
              <input id="name" name="name" required placeholder="Dana Smith" className={inputClass} />
            </Field>
            <Field label="Email" htmlFor="email" hint="Optional. Shown on statements.">
              <input id="email" name="email" type="email" placeholder="dana@example.com" className={inputClass} />
            </Field>
          </ActionForm>
        </Card>

        <Card title="Your owners" className="lg:col-span-2">
          {owners.length === 0 ? (
            <p className="text-sm text-ink-500">No owners yet. Add the first one to start preparing statements.</p>
          ) : (
            <TableWrap>
              <table className={tableClass}>
                <thead>
                  <tr>
                    <th className={thClass}>Name</th>
                    <th className={thClass}>Email</th>
                    <th className={`${thClass} text-right`}>Properties</th>
                    <th className={thClass}>
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-ink-100">
                  {owners.map((owner) => (
                    <tr key={owner.id}>
                      <td className={tdClass}>
                        <Link href={`/owners/${owner.id}`} className="font-medium text-ink-900 hover:underline">
                          {owner.name}
                        </Link>
                      </td>
                      <td className={tdClass}>{owner.email ?? "—"}</td>
                      <td className={`${tdClass} tabular text-right`}>{owner.propertyCount}</td>
                      <td className={`${tdClass} text-right whitespace-nowrap`}>
                        <ButtonLink href={`/statements/${owner.id}?month=${month}`} variant="secondary" size="sm">
                          Statement
                        </ButtonLink>{" "}
                        <ButtonLink href={`/owners/${owner.id}`} variant="ghost" size="sm">
                          Edit
                        </ButtonLink>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </TableWrap>
          )}
        </Card>
      </div>
    </>
  );
}
