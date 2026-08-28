import { apiFetch } from "@/lib/api/client";
import type {
  DoseLog,
  MedicationReminder,
  MedicationReminderCreate,
  MedicationReminderUpdate,
  UpcomingDose,
} from "@/lib/api/types";

export function listMedicationReminders(
  token: string,
  params?: { family_member_id?: string; status?: string }
) {
  return apiFetch<MedicationReminder[]>("/medications", { token, query: params });
}

export function getMedicationReminder(token: string, id: string) {
  return apiFetch<MedicationReminder>(`/medications/${id}`, { token });
}

export function createMedicationReminder(token: string, body: MedicationReminderCreate) {
  return apiFetch<MedicationReminder>("/medications", { method: "POST", token, body });
}

export function updateMedicationReminder(token: string, id: string, body: MedicationReminderUpdate) {
  return apiFetch<MedicationReminder>(`/medications/${id}`, { method: "PATCH", token, body });
}

export function deleteMedicationReminder(token: string, id: string) {
  return apiFetch<void>(`/medications/${id}`, { method: "DELETE", token });
}

export function listUpcomingDoses(token: string, params?: { family_member_id?: string; hours_ahead?: number }) {
  return apiFetch<UpcomingDose[]>("/medications/upcoming/all", { token, query: params });
}

export function setDoseStatus(
  token: string,
  reminderId: string,
  body: { status: "taken" | "skipped"; scheduled_at: string }
) {
  return apiFetch<DoseLog>(`/medications/${reminderId}/doses/status`, { method: "POST", token, body });
}

export function listDoseLogs(token: string, reminderId: string, since?: string) {
  return apiFetch<DoseLog[]>(`/medications/${reminderId}/doses`, { token, query: since ? { since } : undefined });
}
