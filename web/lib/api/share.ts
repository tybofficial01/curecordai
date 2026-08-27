import { apiFetch } from "@/lib/api/client";

export interface PublicShareContact {
  full_name: string;
  relationship: string | null;
  phone_number: string;
}

export interface PublicShareAllergy {
  substance_name: string;
  criticality: string | null;
}

export interface PublicShareCondition {
  condition_name: string;
}

export interface PublicShareMedication {
  display_name: string;
  dosage_instruction: string | null;
}

export interface PublicShareObservation {
  observation_name: string;
  value_quantity: number | null;
  value_string: string | null;
  value_unit: string | null;
  effective_datetime: string | null;
}

export interface PublicShareEncounter {
  title: string;
  start_datetime: string | null;
}

export interface PublicSharePayload {
  expired: boolean;
  patient_name?: string | null;
  blood_group?: string | null;
  scope?: string;
  expires_at?: string;
  allergies?: PublicShareAllergy[];
  conditions?: PublicShareCondition[];
  medications?: PublicShareMedication[];
  observations?: PublicShareObservation[];
  encounters?: PublicShareEncounter[];
  emergency_contacts?: PublicShareContact[];
}

export interface DoctorInstructionSubmit {
  doctor_name: string;
  doctor_institution: string;
  instructions: string;
}

// No auth token is ever passed to these - the share link itself is the credential.
export function getPublicShare(token: string) {
  return apiFetch<PublicSharePayload>(`/share/view/${encodeURIComponent(token)}/data`);
}

export function submitDoctorInstructions(token: string, body: DoctorInstructionSubmit) {
  return apiFetch<{ status: string }>(`/share/view/${encodeURIComponent(token)}/instructions`, {
    method: "POST",
    body,
  });
}
