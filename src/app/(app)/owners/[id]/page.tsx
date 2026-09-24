import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { ActionForm } from "@/components/action-form";
import { ConfirmButton } from "@/components/confirm-button";
import { buttonClass, ButtonLink, Card, Field, inputClass, PageHeader } from "@/components/ui";
import { describeRule } from "@/lib/commission";
import { defaultStatementMonth } from "@/lib/dates";
import { deleteOwnerAction, updateOwnerAction } from "@/server/actions/owners";
import { createPortalLinkAction, revokePortalLinkAction } from "@/server/actions/statements";
import { appUrl } from "@/server/env";
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
            <Field label="Email" htmlFor="email" hint="Needed to email statements.">
              <input id="email" name="email" type="email" defaultValue={owner.email ?? ""} className={inputClass} />
            </Field>
          </ActionForm>
        </Card>

        <Card title="Properties">
          {owned.length === 0 ? (
            <p className="text-sm text-ink-500">
              No properties yet. Open a{" "}
              <Link href="/properties" className="underline">
                property
              </Link>{" "}
              and choose {owner.name} as its owner.
            </p>
          ) : (
            <ul className="divide-y divide-ink-100">
              {owned.map((p) => (
                <li key={p.id} className="py-2 text-sm">
                  <Link href={`/properties/${p.id}`} className="font-medium text-ink-900 hover:underline">
                    {p.name}
                  </Link>
                  <div className="text-ink-500">{describeRule(propertyRule(p))}</div>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <Card
        title="Owner portal"
        description="A private link where the owner can see and download every statement you have sent them. No login needed."
        className="mt-6"
      >
        {owner.portalToken ? (
          <div className="space-y-3">
            <label htmlFor="portalLink" className="sr-only">
              Portal link
            </label>
            <input id="portalLink" readOnly value={`${appUrl()}/o/${owner.portalToken}`} className={`${inputClass} font-mono text-xs`} />
            <div className="flex flex-wrap items-center gap-3">
              <a href={`/o/${owner.portalToken}`} target="_blank" rel="noreferrer" className={buttonClass("secondary", "sm")}>
                Open portal
              </a>
              <form action={revokePortalLinkAction.bind(null, owner.id)}>
                <ConfirmButton label="Turn off link" pendingLabel="Turning off…" confirmMessage="Turn off this link? The owner won't be able to open it anymore." />
              </form>
            </div>
            <p className="text-xs text-ink-500">Statement emails include this link. Turning it off and on again creates a new link.</p>
          </div>
        ) : (
          <form action={createPortalLinkAction.bind(null, owner.id)}>
            <button type="submit" className={buttonClass("secondary")}>
              Create portal link
            </button>
          </form>
        )}
      </Card>

      <Card title="Delete owner" className="mt-6">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <p className="text-sm text-ink-600">Their properties and bookings are kept; the properties just won&apos;t have an owner.</p>
          <form action={deleteOwnerAction.bind(null, owner.id)}>
            <ConfirmButton label="Delete owner" confirmMessage={`Delete ${owner.name}? Their properties will have no owner.`} />
          </form>
        </div>
      </Card>
    </>
  );
}
