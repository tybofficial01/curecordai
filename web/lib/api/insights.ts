import { apiFetch } from "@/lib/api/client";
import type { HealthSummary, ObservationTrend } from "@/lib/api/types";

export function getHealthSummary(token: string, familyMemberId?: string) {
  return apiFetch<HealthSummary>("/insights/summary", { token, query: { family_member_id: familyMemberId } });
}

export function getObservationTrend(token: string, loincCode: string, days = 90, familyMemberId?: string) {
  return apiFetch<ObservationTrend>(`/insights/trends/${loincCode}`, {
    token,
    query: { days, family_member_id: familyMemberId },
  });
}

export interface HealthOverviewCondition {
  condition_name: string;
  clinical_status: string;
  icd11_code: string | null;
}

export interface HealthOverviewMedication {
  medication_name_raw: string;
  dosage_instruction: string | null;
  dose_frequency: string | null;
}

export interface HealthOverviewAllergy {
  substance_name: string;
  reaction_description: string | null;
  criticality: string | null;
}

export interface HealthOverviewObservation {
  observation_name: string;
  value_quantity: number | null;
  value_unit: string | null;
  value_string: string | null;
}

export interface HealthOverview {
  narrative_summary: string | null;
  conditions: HealthOverviewCondition[];
  medications: HealthOverviewMedication[];
  allergies: HealthOverviewAllergy[];
  recent_observations: HealthOverviewObservation[];
}

// Comprehensive whole-person overview — an AI narrative built from everything active across
// all of the patient's records, not a single document's summary. Mirrors the mobile app's
// Home → "View Summary" screen.
export function getHealthOverview(token: string, familyMemberId?: string) {
  return apiFetch<HealthOverview>("/insights/health-overview", { token, query: { family_member_id: familyMemberId } });
}
