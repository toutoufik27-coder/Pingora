"use client";

import { useFormStatus } from "react-dom";
import { buttonClass } from "./ui";

/** Submit button that asks for confirmation before a destructive action. */
export function ConfirmButton({
  label,
  confirmMessage,
  pendingLabel = "Deleting…",
}: {
  label: string;
  confirmMessage: string;
  pendingLabel?: string;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      disabled={pending}
      className={buttonClass("danger", "sm")}
      onClick={(event) => {
        if (!window.confirm(confirmMessage)) event.preventDefault();
      }}
    >
      {pending ? pendingLabel : label}
    </button>
  );
}
