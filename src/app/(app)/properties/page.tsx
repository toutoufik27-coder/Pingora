import type { Metadata } from "next";
import Link from "next/link";
import { Alert, Badge, ButtonLink, Card, EmptyState, PageHeader, TableWrap, tableClass, tdClass, thClass } from "@/components/ui";
import { describeRule } from "@/lib/commission";
import { PAYOUT_FLOW_SHORT_LABELS } from "@/lib/domain";
import { getAppContext } from "@/server/context";
import { listProperties, propertyRule } from "@/server/properties";

export const metadata: Metadata = { title: "Properties" };

export default async function PropertiesPage() {
  const { db, workspace } = await getAppContext();
  const properties = await listProperties(db, workspace.id);
  const withoutOwner = properties.filter((p) => !p.ownerId).length;

  return (
    <>
      <PageHeader
        title="Properties"
        description="Properties are created from the listings in your Airbnb imports. Set the owner and your fee for each one."
      />

      {properties.length === 0 ? (
        <EmptyState title="No properties yet" action={<ButtonLink href="/import">Import from Airbnb</ButtonLink>}>
          Import your Airbnb transaction history and each listing becomes a property here.
        </EmptyState>
      ) : (
        <>
          {withoutOwner > 0 ? (
            <div className="mb-4">
              <Alert title={`${withoutOwner} propert${withoutOwner === 1 ? "y needs" : "ies need"} an owner`}>
                Bookings of a property without an owner don&apos;t appear on any statement.
              </Alert>
            </div>
          ) : null}
          <Card>
            <TableWrap>
              <table className={tableClass}>
                <thead>
                  <tr>
                    <th className={thClass}>Property</th>
                    <th className={thClass}>Owner</th>
                    <th className={thClass}>Your fee</th>
                    <th className={thClass}>Payouts</th>
                    <th className={`${thClass} text-right`}>Transactions</th>
                    <th className={thClass}>
                      <span className="sr-only">Actions</span>
                    </th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-ink-100">
                  {properties.map((p) => (
                    <tr key={p.id}>
                      <td className={tdClass}>
                        <Link href={`/properties/${p.id}`} className="font-medium text-ink-900 hover:underline">
                          {p.name}
                        </Link>
                        {p.listingNames.some((l) => l !== p.name) ? (
                          <div className="text-xs text-ink-500">Airbnb: {p.listingNames.join(", ")}</div>
                        ) : null}
                      </td>
                      <td className={tdClass}>{p.ownerName ?? <Badge tone="warning">No owner</Badge>}</td>
                      <td className={`${tdClass} max-w-xs`}>{describeRule(propertyRule(p))}</td>
                      <td className={tdClass}>{PAYOUT_FLOW_SHORT_LABELS[p.payoutFlow]}</td>
                      <td className={`${tdClass} tabular text-right`}>{p.transactionCount}</td>
                      <td className={`${tdClass} text-right`}>
                        <ButtonLink href={`/properties/${p.id}`} variant="secondary" size="sm">
                          Edit
                        </ButtonLink>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </TableWrap>
          </Card>
        </>
      )}
    </>
  );
}
