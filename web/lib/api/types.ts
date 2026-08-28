// Mirrors backend Pydantic schemas exactly - see be/app/schemas/*.py and be/app/api/v1/*.py

export interface AuthUser {
  id: string;
  phone_number: string | null;
  email: string | null;
  auth_provider: string;
  is_active: boolean;
  is_email_verified: boolean;
  is_phone_verified: boolean;
  data_region: string;
  created_at: string;
}

export interface AuthTokenResult {
  user: AuthUser;
  access_token: string;
  token_type: string;
  expires_at: string;
}

export interface OtpSendResponse {
  message: string;
  expires_in_seconds: number;
}

export interface OtpVerifyResult {
  verified: boolean;
  is_new_user: boolean;
  otp_verified_token?: string;
  // present only when is_new_user is false - routed through the token proxy
  user?: AuthUser;
  access_token?: string;
  expires_at?: string;
}

export interface EmailOtpVerifyResponse {
  verified: boolean;
  email_verified_token: string;
}

export interface ProfileOut {
  id: string;
  user_id: string;
  patient_id_display: string | null;
  full_name: string;
  date_of_birth: string | null;
  gender: string | null;
  height_cm: number | null;
  weight_kg: number | null;
  blood_group: string | null;
  bmi: number | null;
  profile_photo_url: string | null;
  profile_completion_pct: number;
  created_at: string;
  updated_at: string;
}

export interface MeOut {
  id: string;
  phone_number: string | null;
  email: string | null;
  auth_provider: string;
  is_active: boolean;
  is_email_verified: boolean;
  is_phone_verified: boolean;
  mfa_enabled: boolean;
  data_region: string;
  last_login_at: string | null;
  created_at: string;
  profile: ProfileOut | null;
}

// Canonical persisted preference value - underscore, not hyphen - shared verbatim with the
// Flutter app and the backend's FullProfile.language / PATCH /profile/preferences body. Kept
// here (rather than only in i18n/language.ts) since this file mirrors backend schemas.
export type AppLanguage = "en" | "ur" | "roman_ur";

export interface FullProfile {
  patient_id_display: string | null;
  profile_photo_url: string | null;
  full_name: string;
  date_of_birth: string | null;
  gender: string | null;
  phone_number: string | null;
  height_cm: number | null;
  weight_kg: number | null;
  blood_group: string | null;
  bmi: number | null;
  language: AppLanguage;
  theme: string;
  biometric_lock: boolean;
  allergies: string | null;
  conditions: string[];
  profile_completion_pct: number;
}

export const BLOOD_GROUPS = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"] as const;
export type BloodGroup = (typeof BLOOD_GROUPS)[number];

export interface FamilyMember {
  id: string;
  owner_user_id: string;
  full_name: string;
  relationship: string;
  role: "caregiver" | "dependent";
  access_level: "full" | "vitals_only" | "read_only";
  date_of_birth: string | null;
  age: number | null;
  gender: string | null;
  blood_group: string | null;
  photo_url: string | null;
  fhir_patient_id: string | null;
  created_at: string;
  updated_at: string;
}

export const RECORD_TYPES = [
  "lab_report",
  "prescription",
  "radiology",
  "discharge_summary",
  "vaccination",
  "insurance",
  "referral",
  "other",
] as const;
export type RecordType = (typeof RECORD_TYPES)[number];

export interface RecordFolder {
  id: string;
  user_id: string;
  name: string;
  icon: string | null;
  sort_order: number;
  created_at: string;
  updated_at: string;
}

export type ProcessingStatus = "pending" | "processing" | "completed" | "failed";

// Mirrors be/app/services/prompts.py ANALYSIS_USER schema - the structured output of
// analyze_observations(), only populated when a record has numeric observations.
export interface RecordAiAnalysisParameter {
  name: string;
  value: string;
  unit: string;
  status: "Healthy" | "Optimal" | "Monitoring" | "Attention" | string;
  explanation: string;
}

export interface RecordAiAnalysis {
  overall_status: "Good" | "Fair" | "Poor" | string;
  overall_explanation: string;
  parameters: RecordAiAnalysisParameter[];
}

export interface MedicalRecord {
  id: string;
  user_id: string;
  family_member_id: string | null;
  folder_id: string | null;
  title: string;
  record_type: RecordType;
  record_date: string | null;
  document_date: string | null;
  file_name: string;
  file_mime_type: string;
  file_size_bytes: number;
  processing_status: ProcessingStatus;
  processing_error: string | null;
  ai_summary: string | null;
  ai_summary_generated_at: string | null;
  ai_analysis: RecordAiAnalysis | null;
  is_dicom: boolean;
  patient_name_on_doc: string | null;
  laboratory_name: string | null;
  issuing_organization: string | null;
  referring_doctor: string | null;
  uploaded_at: string;
  created_at: string;
  download_url: string | null;
}

export interface RecordClinicalData {
  conditions: Record<string, unknown>[];
  medications: Record<string, unknown>[];
  observations: Record<string, unknown>[];
  allergies: Record<string, unknown>[];
  encounters: Record<string, unknown>[];
}

export interface MedicalRecordFull extends MedicalRecord {
  clinical: RecordClinicalData | null;
}

// ── Medication reminders ────────────────────────────────────────────────────

export const MEDICATION_FREQUENCY_TYPES = ["daily", "specific_days", "interval", "as_needed"] as const;
export type MedicationFrequencyType = (typeof MEDICATION_FREQUENCY_TYPES)[number];

export type MedicationReminderStatus = "active" | "paused" | "completed";

export interface MedicationReminder {
  id: string;
  user_id: string;
  family_member_id: string | null;
  source: "manual" | "document";
  medication_request_id: string | null;
  source_record_id: string | null;
  medication_name: string;
  dosage: string | null;
  form: string | null;
  instructions: string | null;
  frequency_type: MedicationFrequencyType;
  days_of_week: number[] | null;
  interval_days: number | null;
  times_of_day: string[];
  timezone: string;
  start_date: string;
  end_date: string | null;
  status: MedicationReminderStatus;
  email_reminders_enabled: boolean;
  push_reminders_enabled: boolean;
  created_at: string;
  updated_at: string;
}

export interface MedicationReminderCreate {
  family_member_id?: string | null;
  source: "manual" | "document";
  medication_request_id?: string | null;
  source_record_id?: string | null;
  medication_name: string;
  dosage?: string | null;
  form?: string | null;
  instructions?: string | null;
  frequency_type: MedicationFrequencyType;
  days_of_week?: number[] | null;
  interval_days?: number | null;
  times_of_day: string[];
  timezone: string;
  start_date: string;
  end_date?: string | null;
  email_reminders_enabled?: boolean;
  push_reminders_enabled?: boolean;
}

export type MedicationReminderUpdate = Partial<
  Omit<MedicationReminderCreate, "source" | "medication_request_id" | "source_record_id">
> & { status?: MedicationReminderStatus };

export interface UpcomingDose {
  reminder_id: string;
  family_member_id: string | null;
  medication_name: string;
  dosage: string | null;
  instructions: string | null;
  scheduled_at: string;
  timezone: string;
  dose_log_id: string | null;
  dose_status: string;
}

export interface DoseLog {
  id: string;
  reminder_id: string;
  family_member_id: string | null;
  scheduled_at: string;
  status: "pending" | "sent" | "taken" | "skipped" | "missed";
  email_sent_at: string | null;
  taken_at: string | null;
  created_at: string;
}

export interface RecordUploadInit {
  record_id: string;
  upload_url: string;
  // Presigned POST fields - send every entry here as a form field in the multipart upload,
  // alongside the file itself (see postFileToS3 in lib/api/records.ts).
  upload_fields: Record<string, string>;
  object_key: string;
  expires_in_seconds: number;
}

export interface ChatSession {
  id: string;
  family_member_id: string | null;
  title: string | null;
  status: string;
  total_messages: number;
  is_pinned: boolean;
  created_at: string;
  updated_at: string;
}

export interface ChatCitation {
  record_id: string;
  title: string;
  record_type: string;
  record_date: string | null;
}

export interface ChatMessage {
  id: string;
  session_id: string;
  role: "user" | "assistant";
  content: string;
  disclaimer_included: boolean;
  model_version: string | null;
  created_at: string;
  citations: ChatCitation[];
}

export const SHARE_SCOPES = ["last_1_year", "last_6_months", "full", "emergency_only"] as const;
export type ShareScope = (typeof SHARE_SCOPES)[number];

export interface ShareSession {
  id: string;
  share_scope: ShareScope;
  status: string;
  expires_at: string;
  expires_in_seconds: number;
  qr_url: string;
  created_at: string;
}

export interface ShareSessionSummary {
  id: string;
  scope: string;
  status: string;
  expires_at: string;
}

export interface DoctorInstruction {
  id: string;
  doctor_name: string;
  doctor_institution: string;
  instructions: string;
  share_scope: string;
  seen_at: string | null;
  created_at: string;
}

export interface Alert {
  id: string;
  user_id: string;
  title: string;
  message: string;
  alert_type: string;
  priority: "low" | "medium" | "high" | "critical" | string;
  category: string;
  is_read: boolean;
  read_at: string | null;
  is_dismissed: boolean;
  linked_entity_type: string | null;
  linked_entity_id: string | null;
  created_at: string;
}

export interface AppSettings {
  id: string;
  user_id: string;
  language: string;
  theme: string;
  biometric_lock_enabled: boolean;
  push_notifications_enabled: boolean;
  email_notifications_enabled: boolean;
  drug_interaction_alerts: boolean;
  lab_result_alerts: boolean;
  vital_threshold_alerts: boolean;
  analytics_opt_in: boolean;
  updated_at: string;
}

export interface HealthSummary {
  total_records: number;
  active_conditions: number;
  active_medications: number;
  active_allergies: number;
  records_this_month: number;
  unread_alerts: number;
}

export interface Allergy {
  id: string;
  family_member_id: string | null;
  substance_name: string;
  category: string | null;
  criticality: string | null;
  clinical_status: string;
}

export interface ObservationTrendPoint {
  date: string;
  value: number;
  unit: string | null;
}

export interface ObservationTrend {
  loinc_code: string;
  observation_name: string;
  points: ObservationTrendPoint[];
}
