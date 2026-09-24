"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { getAppContext } from "../context";
import { commitImport, deleteImport, previewImport, type CommitImportResult, type ImportPreview } from "../imports";
import { idField } from "./fields";

const MAX_CSV_LENGTH = 9_500_000;

const csvText = z.string().min(1, "The file is empty.").max(MAX_CSV_LENGTH, "The file is too large. Export a shorter date range.");
const dateOrder = z.enum(["MDY", "DMY", "YMD"]).optional();

export async function previewImportAction(text: string, order?: string): Promise<ImportPreview> {
  const parsed = z.object({ text: csvText, order: dateOrder }).safeParse({ text, order });
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const { db, workspace } = await getAppContext();
  return previewImport(db, workspace.id, parsed.data.text, { dateOrder: parsed.data.order });
}

const commitSchema = z.object({
  csvText,
  fileName: z.string().trim().min(1).max(255),
  dateOrder,
  mappings: z.record(z.string().max(500), z.string().max(100)),
});

export async function commitImportAction(input: z.input<typeof commitSchema>): Promise<CommitImportResult> {
  const parsed = commitSchema.safeParse(input);
  if (!parsed.success) return { ok: false, error: parsed.error.issues[0].message };
  const { db, workspace } = await getAppContext();
  const result = await commitImport(db, workspace, parsed.data);
  if (result.ok) revalidatePath("/", "layout");
  return result;
}

export async function deleteImportAction(importId: string): Promise<void> {
  const id = idField.parse(importId);
  const { db, workspace } = await getAppContext();
  await deleteImport(db, workspace.id, id);
  revalidatePath("/", "layout");
}
