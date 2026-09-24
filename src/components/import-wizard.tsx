"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { formatDate, type DateOrder } from "@/lib/dates";
import { commitImportAction, previewImportAction } from "@/server/actions/imports";
import type { CommitImportResult, ImportPreview } from "@/server/imports";
import { Alert, Badge, buttonClass, inputClass, tableClass, tdClass, thClass } from "./ui";

const NEW_PROPERTY = "new";
const MAX_FILE_BYTES = 9 * 1024 * 1024;
const SAMPLE_URL = "/samples/airbnb-transaction-history-sample.csv";

type Preview = Extract<ImportPreview, { ok: true }>;

const DATE_ORDER_LABELS: Record<DateOrder, string> = {
  MDY: "Month/day/year (US)",
  DMY: "Day/month/year",
  YMD: "Year-month-day",
};

export function ImportWizard({ offerSample }: { offerSample: boolean }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [file, setFile] = useState<{ name: string; text: string } | null>(null);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [dateOrder, setDateOrder] = useState<DateOrder | undefined>(undefined);
  const [mappings, setMappings] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [result, setResult] = useState<Extract<CommitImportResult, { ok: true }> | null>(null);

  function runPreview(next: { name: string; text: string }, order?: DateOrder) {
    setError(null);
    setResult(null);
    startTransition(async () => {
      const response = await previewImportAction(next.text, order);
      if (!response.ok) {
        setPreview(null);
        setError(response.error);
        return;
      }
      setFile(next);
      setDateOrder(order);
      setPreview(response);
      setMappings(Object.fromEntries(response.listings.filter((l) => !l.propertyId).map((l) => [l.name, NEW_PROPERTY])));
    });
  }

  async function onFileChosen(input: HTMLInputElement) {
    const chosen = input.files?.[0];
    if (!chosen) return;
    if (chosen.size > MAX_FILE_BYTES) {
      setError("That file is larger than 9 MB. Export a shorter date range from Airbnb and try again.");
      return;
    }
    runPreview({ name: chosen.name, text: await chosen.text() });
  }

  function useSample() {
    setError(null);
    startTransition(async () => {
      const response = await fetch(SAMPLE_URL);
      if (!response.ok) {
        setError("Could not load the sample file.");
        return;
      }
      runPreview({ name: "airbnb-transaction-history-sample.csv", text: await response.text() });
    });
  }

  function commit() {
    if (!file || !preview) return;
    setError(null);
    startTransition(async () => {
      const response = await commitImportAction({ csvText: file.text, fileName: file.name, dateOrder, mappings });
      if (!response.ok) {
        setError(response.error);
        return;
      }
      setResult(response);
      setPreview(null);
      setFile(null);
      router.refresh();
    });
  }

  return (
    <div className="space-y-5">
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
        <label className={`${buttonClass("primary")} relative cursor-pointer`}>
          <input
            type="file"
            accept=".csv,text/csv"
            className="sr-only"
            disabled={pending}
            onChange={(event) => {
              void onFileChosen(event.currentTarget);
              event.currentTarget.value = "";
            }}
          />
          Choose Airbnb CSV file…
        </label>
        {offerSample ? (
          <button type="button" className={buttonClass("secondary")} onClick={useSample} disabled={pending}>
            Try the sample file
          </button>
        ) : null}
        {pending ? <span className="text-sm text-ink-500">Working…</span> : null}
      </div>

      {error ? (
        <Alert tone="danger" title="This file can't be imported">
          {error}
        </Alert>
      ) : null}

      {result ? (
        <Alert tone="info" title="Import complete">
          <p>
            Added {result.insertedCount} transaction{result.insertedCount === 1 ? "" : "s"}
            {result.duplicateCount > 0 ? `, skipped ${result.duplicateCount} already imported` : ""}
            {result.skippedCount > 0 ? `, ignored ${result.skippedCount} payout and tax lines` : ""}
            {result.createdProperties > 0
              ? `, and created ${result.createdProperties} new propert${result.createdProperties === 1 ? "y" : "ies"}`
              : ""}
            .
          </p>
          <p className="mt-2 flex flex-wrap gap-3">
            <Link href="/properties" className="font-medium underline">
              Assign owners and fees →
            </Link>
            <Link href="/statements" className="font-medium underline">
              View owner statements →
            </Link>
          </p>
        </Alert>
      ) : null}

      {preview && file ? (
        <PreviewPanel
          fileName={file.name}
          preview={preview}
          mappings={mappings}
          pending={pending}
          onMappingChange={(listing, value) => setMappings((m) => ({ ...m, [listing]: value }))}
          onDateOrderChange={(order) => runPreview(file, order)}
          onCommit={commit}
          onCancel={() => {
            setPreview(null);
            setFile(null);
          }}
        />
      ) : null}
    </div>
  );
}

function PreviewPanel({
  fileName,
  preview,
  mappings,
  pending,
  onMappingChange,
  onDateOrderChange,
  onCommit,
  onCancel,
}: {
  fileName: string;
  preview: Preview;
  mappings: Record<string, string>;
  pending: boolean;
  onMappingChange: (listing: string, value: string) => void;
  onDateOrderChange: (order: DateOrder) => void;
  onCommit: () => void;
  onCancel: () => void;
}) {
  const unmapped = preview.listings.filter((l) => !l.propertyId);
  return (
    <div className="space-y-5 rounded-xl border border-ink-200 bg-white p-5 shadow-sm">
      <div className="flex flex-col gap-1 sm:flex-row sm:items-baseline sm:justify-between">
        <h3 className="text-base font-semibold text-ink-900">Review {fileName}</h3>
        {preview.dateRange ? (
          <span className="text-sm text-ink-500">
            {formatDate(preview.dateRange.start)} – {formatDate(preview.dateRange.end)}
          </span>
        ) : null}
      </div>

      <dl className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Stat label="New transactions" value={preview.newCount} highlight />
        <Stat label="Already imported" value={preview.duplicateCount} />
        <Stat label="Payouts & taxes ignored" value={preview.skippedCount} />
        <Stat label="Rows with problems" value={preview.errorCount} />
      </dl>

      <div className="flex flex-col gap-2 text-sm sm:flex-row sm:items-center">
        <label htmlFor="dateOrder" className="text-ink-600">
          Dates in this file are read as
        </label>
        <select
          id="dateOrder"
          className={`${inputClass} sm:w-56`}
          value={preview.dateOrder}
          disabled={pending}
          onChange={(event) => onDateOrderChange(event.target.value as DateOrder)}
        >
          {Object.entries(DATE_ORDER_LABELS).map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
        {preview.dateOrderSource === "ambiguous" ? <Badge tone="warning">Could not tell for sure — please check</Badge> : null}
      </div>

      {preview.currencies.length > 1 ? (
        <Alert title="Several currencies">
          This file mixes {preview.currencies.join(", ")}. Statements add amounts together, so import one currency per owner.
        </Alert>
      ) : null}

      <div>
        <h4 className="mb-2 text-sm font-semibold text-ink-900">Listings</h4>
        <p className="mb-3 text-sm text-ink-600">
          Each Airbnb listing belongs to one property. New listings become new properties unless you link them to an existing one (for
          example after renaming a listing on Airbnb).
        </p>
        <div className="overflow-x-auto">
          <table className={tableClass}>
            <thead>
              <tr>
                <th className={thClass}>Airbnb listing</th>
                <th className={`${thClass} text-right`}>Rows</th>
                <th className={thClass}>Property</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-ink-100">
              {preview.listings.map((listing) => (
                <tr key={listing.name}>
                  <td className={`${tdClass} font-medium text-ink-900`}>{listing.name}</td>
                  <td className={`${tdClass} tabular text-right`}>{listing.rows}</td>
                  <td className={tdClass}>
                    {listing.propertyId ? (
                      <span className="text-ink-600">Linked to {listing.propertyName}</span>
                    ) : (
                      <select
                        aria-label={`Property for ${listing.name}`}
                        className={`${inputClass} max-w-xs`}
                        value={mappings[listing.name] ?? NEW_PROPERTY}
                        onChange={(event) => onMappingChange(listing.name, event.target.value)}
                      >
                        <option value={NEW_PROPERTY}>Create a new property</option>
                        {preview.properties.map((p) => (
                          <option key={p.id} value={p.id}>
                            Link to {p.name}
                          </option>
                        ))}
                      </select>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      <details className="text-sm">
        <summary className="cursor-pointer font-medium text-ink-700">Transaction types in this file</summary>
        <ul className="mt-2 space-y-1 text-ink-600">
          {preview.types.map((t) => (
            <li key={t.type} className="flex items-center gap-2">
              <span className="tabular w-10 text-right">{t.count}</span>
              <span>{t.type}</span>
              {t.included ? <Badge tone="brand">on statements</Badge> : <Badge>ignored</Badge>}
            </li>
          ))}
        </ul>
      </details>

      {preview.rowErrors.length > 0 ? (
        <Alert title={`${preview.errorCount} row${preview.errorCount === 1 ? "" : "s"} will be skipped`}>
          <ul className="list-disc space-y-0.5 pl-5">
            {preview.rowErrors.map((e) => (
              <li key={e.row}>
                Row {e.row}: {e.message}
              </li>
            ))}
          </ul>
        </Alert>
      ) : null}

      <div className="flex flex-wrap items-center gap-3 border-t border-ink-100 pt-4">
        <button type="button" className={buttonClass("primary")} onClick={onCommit} disabled={pending || preview.newCount === 0}>
          {preview.newCount === 0 ? "Nothing new to import" : `Import ${preview.newCount} transaction${preview.newCount === 1 ? "" : "s"}`}
        </button>
        <button type="button" className={buttonClass("ghost")} onClick={onCancel} disabled={pending}>
          Cancel
        </button>
        {unmapped.length > 0 ? (
          <span className="text-sm text-ink-500">
            {unmapped.length} new listing{unmapped.length === 1 ? "" : "s"} to set up
          </span>
        ) : null}
      </div>
    </div>
  );
}

function Stat({ label, value, highlight = false }: { label: string; value: number; highlight?: boolean }) {
  return (
    <div className={`rounded-lg px-3 py-2 ${highlight ? "bg-brand-50" : "bg-ink-50"}`}>
      <dt className="text-xs text-ink-500">{label}</dt>
      <dd className={`tabular text-xl font-semibold ${highlight ? "text-brand-700" : "text-ink-900"}`}>{value}</dd>
    </div>
  );
}
