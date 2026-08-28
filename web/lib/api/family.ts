import { apiFetch } from "@/lib/api/client";
import type { FamilyMember } from "@/lib/api/types";

export function listFamilyMembers(token: string) {
  return apiFetch<FamilyMember[]>("/family", { token });
}

export function createFamilyMember(
  token: string,
  body: {
    full_name: string;
    relationship: string;
    role: "caregiver" | "dependent";
    access_level: "full" | "vitals_only" | "read_only";
    date_of_birth?: string | null;
    gender?: string | null;
    blood_group?: string | null;
  }
) {
  return apiFetch<FamilyMember>("/family", { method: "POST", token, body });
}

export function updateFamilyMember(
  token: string,
  id: string,
  body: {
    full_name?: string;
    relationship?: string;
    access_level?: "full" | "vitals_only" | "read_only";
    date_of_birth?: string | null;
    gender?: string | null;
    blood_group?: string | null;
  }
) {
  return apiFetch<FamilyMember>(`/family/${id}`, { method: "PATCH", token, body });
}

export function deleteFamilyMember(token: string, id: string) {
  return apiFetch<void>(`/family/${id}`, { method: "DELETE", token });
}
