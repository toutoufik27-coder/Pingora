import type { Metadata } from "next";
import { ActionForm } from "@/components/action-form";
import { Card, Field, inputClass, PageHeader } from "@/components/ui";
import { changePasswordAction, deleteAccountAction, updateProfileAction } from "@/server/actions/account";
import { PASSWORD_MIN_LENGTH } from "@/server/auth/accounts";
import { getAppContext } from "@/server/context";

export const metadata: Metadata = { title: "Account" };

export default async function AccountPage() {
  const { user, workspace } = await getAppContext({ allowInactive: true });

  return (
    <>
      <PageHeader title="Account" description={`Signed in as ${user.email} for ${workspace.name}.`} />

      <div className="grid max-w-3xl gap-6">
        <Card title="Profile">
          <ActionForm action={updateProfileAction} submitLabel="Save profile" className="space-y-4">
            <Field label="Your name" htmlFor="name">
              <input id="name" name="name" required defaultValue={user.name} autoComplete="name" className={inputClass} />
            </Field>
            <Field label="Email" htmlFor="email" hint="Used to log in, and as the reply-to address on statement emails.">
              <input id="email" name="email" type="email" required defaultValue={user.email} autoComplete="email" className={inputClass} />
            </Field>
          </ActionForm>
        </Card>

        <Card title="Password">
          <ActionForm action={changePasswordAction} submitLabel="Change password" className="space-y-4">
            <Field label="Current password" htmlFor="current">
              <input id="current" name="current" type="password" required autoComplete="current-password" className={inputClass} />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="New password" htmlFor="password" hint={`At least ${PASSWORD_MIN_LENGTH} characters.`}>
                <input id="password" name="password" type="password" required minLength={PASSWORD_MIN_LENGTH} autoComplete="new-password" className={inputClass} />
              </Field>
              <Field label="Repeat new password" htmlFor="confirm">
                <input id="confirm" name="confirm" type="password" required autoComplete="new-password" className={inputClass} />
              </Field>
            </div>
          </ActionForm>
        </Card>

        <Card title="Delete account" description="Permanently deletes your business, owners, bookings, statements and login. This can't be undone.">
          <ActionForm action={deleteAccountAction} submitLabel="Delete my account" pendingLabel="Deleting…" className="space-y-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Password" htmlFor="deletePassword">
                <input id="deletePassword" name="password" type="password" required autoComplete="current-password" className={inputClass} />
              </Field>
              <Field label='Type "DELETE" to confirm' htmlFor="confirmDelete">
                <input id="confirmDelete" name="confirm" required autoComplete="off" className={inputClass} />
              </Field>
            </div>
            <p className="text-xs text-slate-500">An active subscription is cancelled automatically.</p>
          </ActionForm>
        </Card>
      </div>
    </>
  );
}
