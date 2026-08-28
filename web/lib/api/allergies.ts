import { apiFetch } from "@/lib/api/client";
import type { Allergy } from "@/lib/api/types";

export function listAllergies(
  token: string,
  params?: { clinical_status?: string; family_member_id?: string }
) {
  return apiFetch<Allergy[]>("/allergies", { token, query: params });
}
