import { apiFetch } from "@/lib/api/client";
import type {
  MedicalRecord,
  MedicalRecordFull,
  RecordFolder,
  RecordType,
  RecordUploadInit,
} from "@/lib/api/types";

export function listRecords(
  token: string,
  query?: { folder_id?: string; record_type?: string; family_member_id?: string }
) {
  return apiFetch<MedicalRecord[]>("/records", { token, query });
}

export function getRecordFull(token: string, id: string) {
  return apiFetch<MedicalRecordFull>(`/records/${id}/full`, { token });
}

export function getRecord(token: string, id: string) {
  return apiFetch<MedicalRecord>(`/records/${id}`, { token });
}

export function updateRecord(
  token: string,
  id: string,
  body: {
    title?: string;
    folder_id?: string | null;
    record_date?: string | null;
    patient_name_on_doc?: string | null;
    laboratory_name?: string | null;
    referring_doctor?: string | null;
  }
) {
  return apiFetch<MedicalRecord>(`/records/${id}`, { method: "PATCH", token, body });
}

export function deleteRecord(token: string, id: string) {
  return apiFetch<void>(`/records/${id}`, { method: "DELETE", token });
}

export function listFolders(token: string) {
  return apiFetch<RecordFolder[]>("/records/folders", { token });
}

export function createFolder(token: string, body: { name: string; icon?: string; sort_order?: number }) {
  return apiFetch<RecordFolder>("/records/folders", { method: "POST", token, body });
}

export function initUpload(
  token: string,
  body: {
    file_name: string;
    file_mime_type: string;
    file_size_bytes: number;
    title?: string;
    record_type?: RecordType;
    folder_id?: string | null;
    family_member_id?: string | null;
    record_date?: string | null;
  },
  signal?: AbortSignal
) {
  return apiFetch<RecordUploadInit>("/records/upload/init", { method: "POST", token, body, signal });
}

export async function postFileToS3(
  uploadUrl: string,
  uploadFields: Record<string, string>,
  file: File,
  signal?: AbortSignal
): Promise<void> {
  const formData = new FormData();
  // S3 enforces the content-length-range policy condition on the actual bytes sent - this is
  // what makes the size limit real (a raw PUT URL had no such enforcement). All policy fields
  // must be appended before the file; S3 requires "file" to be the last field in the form.
  for (const [key, value] of Object.entries(uploadFields)) {
    formData.append(key, value);
  }
  formData.append("file", file);

  const response = await fetch(uploadUrl, { method: "POST", body: formData, signal });
  if (!response.ok) {
    throw new Error(`File upload to storage failed (${response.status})`);
  }
}

export async function computeSha256Hex(file: File): Promise<string> {
  const buffer = await file.arrayBuffer();
  const digest = await crypto.subtle.digest("SHA-256", buffer);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function confirmUpload(token: string, recordId: string, fileHash?: string, signal?: AbortSignal) {
  return apiFetch<MedicalRecord>(`/records/${recordId}/upload/confirm`, {
    method: "POST",
    token,
    body: { file_hash: fileHash },
    signal,
  });
}
