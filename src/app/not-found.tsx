import { ButtonLink, EmptyState } from "@/components/ui";

export default function NotFound() {
  return (
    <div className="mx-auto max-w-xl px-4 py-16">
    <EmptyState title="Page not found" action={<ButtonLink href="/dashboard">Go to your dashboard</ButtonLink>}>
      The owner, property or page you were looking for doesn&apos;t exist anymore.
    </EmptyState>
    </div>
  );
}
