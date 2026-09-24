import type { ReactNode } from "react";

/** Readable long-form layout for the terms and privacy pages. */
export function LegalPage({ title, updated, children }: { title: string; updated: string; children: ReactNode }) {
  return (
    <article className="mx-auto max-w-3xl px-4 py-16 text-ink-700 md:px-8 [&_a]:underline [&_h2]:mt-10 [&_h2]:text-xl [&_h2]:font-semibold [&_h2]:text-ink-900 [&_li]:mt-1 [&_p]:mt-4 [&_ul]:mt-4 [&_ul]:list-disc [&_ul]:pl-6">
      <h1 className="text-3xl font-bold tracking-tight text-ink-900">{title}</h1>
      <p className="text-sm text-ink-500">Last updated {updated}</p>
      {children}
    </article>
  );
}
