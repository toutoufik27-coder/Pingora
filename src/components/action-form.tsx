"use client";

import { useActionState, type ReactNode } from "react";
import { IDLE, type ActionState } from "@/lib/action-state";
import { buttonClass } from "./ui";

/** A form bound to a server action that reports success or an error inline. */
export function ActionForm({
  action,
  submitLabel,
  pendingLabel = "Saving…",
  children,
  className = "",
}: {
  action: (state: ActionState, formData: FormData) => Promise<ActionState>;
  submitLabel: string;
  pendingLabel?: string;
  children: ReactNode;
  className?: string;
}) {
  const [state, formAction, pending] = useActionState(action, IDLE);
  return (
    <form action={formAction} className={className}>
      {children}
      <div className="mt-5 flex flex-wrap items-center gap-3">
        <button type="submit" className={buttonClass("primary")} disabled={pending}>
          {pending ? pendingLabel : submitLabel}
        </button>
        <p aria-live="polite" className="text-sm">
          {state.status === "error" ? <span className="text-red-700">{state.message}</span> : null}
          {state.status === "success" ? <span className="text-brand-700">{state.message}</span> : null}
        </p>
      </div>
    </form>
  );
}
