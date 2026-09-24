"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";
import { failure, success, type ActionState } from "@/lib/action-state";
import { getAppContext } from "../context";
import { createOwner, deleteOwner, updateOwner } from "../owners";
import { firstIssue, idField, readFields } from "./fields";

const ownerSchema = z.object({
  name: z.string().trim().min(1, "Enter the owner's name.").max(200, "That name is too long."),
  email: z
    .string()
    .trim()
    .max(320)
    .refine((v) => v === "" || z.email().safeParse(v).success, "Enter a valid email address or leave it empty.")
    .transform((v) => v || null),
});

export async function createOwnerAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const parsed = ownerSchema.safeParse(readFields(formData, ["name", "email"]));
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, workspace } = await getAppContext();
  await createOwner(db, workspace.id, parsed.data);
  revalidatePath("/", "layout");
  return success(`Added ${parsed.data.name}.`);
}

export async function updateOwnerAction(ownerId: string, _state: ActionState, formData: FormData): Promise<ActionState> {
  const id = idField.safeParse(ownerId);
  const parsed = ownerSchema.safeParse(readFields(formData, ["name", "email"]));
  if (!id.success) return failure("Unknown owner.");
  if (!parsed.success) return failure(firstIssue(parsed.error));
  const { db, workspace } = await getAppContext();
  if (!(await updateOwner(db, workspace.id, id.data, parsed.data))) return failure("This owner no longer exists.");
  revalidatePath("/", "layout");
  return success("Saved.");
}

export async function deleteOwnerAction(ownerId: string): Promise<void> {
  const id = idField.parse(ownerId);
  const { db, workspace } = await getAppContext();
  await deleteOwner(db, workspace.id, id);
  revalidatePath("/", "layout");
  redirect("/owners");
}
