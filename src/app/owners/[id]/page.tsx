import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ActionForm } from "@/components/action-form";
import { ConfirmButton } from "@/components/confirm-button";
import { ButtonLink, Card, Field, inputClass, PageHeader } from "@/components/ui";
import { describeRule } from "@/lib/commission";
import { defaultStatementMonth } from "@/lib/dates";
import { deleteOwnerAction, updateOwnerAction } from "@/server/actions/owners";
import { getAppContext } from "@/server/context";
import { getOwner } from "@/server/owners";
import { listProperties, propertyRule } from "@/server/properties";

export const metadata: Metadata = { title: "Owner" };

export default async function OwnerPage({ params }: PageProps<"/owners/[id]">) {
  const { id } = await params;
  const { db, workspace } = await getAppContext();
  const [owner, properties] = await Promise.all([getOwner(db, workspace.id, id), listProperties(db, workspace.id)]);
  if (!owner) notFound();
  const owned = properties.filter((p) => p.ownerId === owner.id);

  return (
    <>
      <PageHeader
        title={owner.name}
        description={
          <Link href="/owners" className="underline">
            All owners
          </Link>
        }
        actions={<ButtonLink href={`/statements/${owner.id}?month=${defaultStatementMonth()}`}>View statement</ButtonLink>}
      />

      <div className="grid gap-6 lg:grid-cols-2">
        <Card title="Details">
          <ActionForm action={updateOwnerAction.bind(null, owner.id)} submitLabel="Save" className="space-y-4">
            <Field label="Name" htmlFor="name">
              <input id="name" name="name" required defaultValue={owner.name} className={inputClass} />
            </Field>
            <Field label="Email" htmlFor="email">
              <input id="email" name="email" type="email" defaultValue={owner.email ?? ""} className={inputClass} />
            </Field>
          </ActionForm>
        </Card>

        <Card title="Properties">
          {owned.length === 0 ? (
            <p className="text-sm text-slate-500">
              No properties yet. Open a{" "}
              <Link href="/properties" className="underline">
                property
              </Link>{" "}
              and choose {owner.name} as its owner.
            </p>
          ) : (
            <ul className="divide-y divide-slate-100">
              {owned.map((p) => (
                <li key={p.id} className="py-2 text-sm">
                  <Link href={`/properties/${p.id}`} className="font-medium text-slate-900 hover:underline">
                    {p.name}
                  </Link>
                  <div className="text-slate-500">{describeRule(propertyRule(p))}</div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <Card title="Delete owner" className="mt-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-sm text-slate-600">Their properties and bookings are kept; the properties just won&apos;t have an owner.</p>
          <form action={deleteOwnerAction.bind(null, owner.id)}>
            <ConfirmButton label="Delete owner" confirmMessage={`Delete ${owner.name}? Their properties will have no owner.`} />
          </form>
        </div>
      </Card>
    </>
  );
}
