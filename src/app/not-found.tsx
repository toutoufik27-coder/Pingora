import { ButtonLink, EmptyState } from "@/components/ui";

export default function NotFound() {
  return (
    <EmptyState title="Page not found" action={<ButtonLink href="/">Back to the dashboard</ButtonLink>}>
      The owner, property or page you were looking for doesn&apos;t exist anymore.
    </EmptyState>
  );
}
