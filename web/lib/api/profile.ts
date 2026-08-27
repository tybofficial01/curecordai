import { apiFetch, API_BASE_URL, errorFromPayload } from "@/lib/api/client";
import type { AppLanguage, FullProfile } from "@/lib/api/types";

export function getProfile(token: string) {
  return apiFetch<FullProfile>("/profile", { token });
}

export function updateProfileInfo(
  token: string,
  body: { full_name: string; date_of_birth?: string | null; gender?: string | null; phone_number: string }
) {
  return apiFetch<FullProfile>("/profile", { method: "PUT", token, body });
}

export function updatePhysicalMetrics(
  token: string,
  body: { height_cm?: number | null; weight_kg?: number | null; blood_group?: string | null }
) {
  return apiFetch<{ bmi: number | null; message: string }>("/profile/physical-metrics", {
    method: "PUT",
    token,
    body,
  });
}

export function updateHealthDetails(token: string, body: { allergies: string; conditions: string[] }) {
  return apiFetch<{ data: null; message: string }>("/profile/health-details", {
    method: "PUT",
    token,
    body,
  });
}

export function updatePreferences(token: string, body: { language: AppLanguage; is_dark_theme: boolean }) {
  return apiFetch<{ data: null; message: string }>("/profile/preferences", { method: "PUT", token, body });
}

export async function uploadAvatar(token: string, file: File): Promise<{ avatar_url: string }> {
  const form = new FormData();
  form.append("file", file);
  const response = await fetch(`${API_BASE_URL}/profile/avatar`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw errorFromPayload(response.status, payload, "Avatar upload failed");
  }
  return payload;
}
