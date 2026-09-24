"use client";

import { useEffect } from "react";
import { buttonClass, EmptyState } from "@/components/ui";

export default function ErrorPage({ error, retry }: { error: Error & { digest?: string }; retry: () => void }) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <EmptyState
      title="Something went wrong"
      action={
        <button type="button" className={buttonClass("primary")} onClick={() => retry()}>
          Try again
        </button>
      }
    >
      {error.digest ? `Error reference: ${error.digest}` : "Please try again. If it keeps happening, reload the page."}
    </EmptyState>
  );
}
