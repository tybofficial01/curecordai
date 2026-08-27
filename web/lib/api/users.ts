import { apiFetch } from "@/lib/api/client";

export interface OnboardingPayload {
  full_name?: string;
  year_of_birth?: number;
  gender?: string;
  height_cm?: number;
  weight_kg?: number;
  blood_group?: string;
  allergies?: string;
  existing_conditions?: string[];
}

export function completeOnboarding(token: string, body: OnboardingPayload) {
  return apiFetch<{ message: string }>("/users/onboarding", {
    method: "POST",
    token,
    body,
  });
}
