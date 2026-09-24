import Link from "next/link";
import { APP_NAME } from "@/lib/brand";

export function Logo({ href = "/" }: { href?: string }) {
  return (
    <Link href={href} className="flex items-center gap-2 font-semibold text-slate-900">
      <span aria-hidden className="grid size-8 place-items-center rounded-lg bg-brand-600 text-sm font-bold text-white">
        CL
      </span>
      {APP_NAME}
    </Link>
  );
}
