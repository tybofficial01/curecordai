"use client";

import { useEffect, useMemo, useState, type FormEvent } from "react";
import Link from "next/link";
import {
  ArrowLeft,
  FileText,
  PencilSimple,
  Plus,
  User,
  UsersThree,
  UploadSimple,
  X,
} from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { listFamilyMembers } from "@/lib/api/family";
import { listRecords, getRecordFull } from "@/lib/api/records";
import { createMedicationReminder } from "@/lib/api/medications";
import { ApiError } from "@/lib/api/client";
import { dayLabels, formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { useToast } from "@/lib/toast/ToastProvider";
import { OnboardingProgress } from "@/components/onboarding/OnboardingProgress";
import { Select } from "@/components/ui/Select";
import type { MedicationFrequencyType } from "@/lib/api/types";

const INPUT_CLS =
  "mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20";

type Step = "who" | "member" | "source" | "document" | "details" | "schedule";

// The step indicator's total count depends on the path taken: adding a family member inserts
// a "member" selection step, and importing from a document inserts a "document" selection step,
// so the same "Add Medication" flow can be 4, 5, or 6 steps long depending on what was chosen.
function stepsForPath(isFamilyPath: boolean, source: "manual" | "document"): Step[] {
  return [
    "who",
    ...(isFamilyPath ? (["member"] as Step[]) : []),
    "source",
    ...(source === "document" ? (["document"] as Step[]) : []),
    "details",
    "schedule",
  ];
}

function AddMedicationModalContent({
  onClose,
  onCreated,
}: {
  onClose: () => void;
  onCreated: () => void;
}) {
  const { getAccessToken } = useAuth();
  const dm = useDashboardMessages();
  const dayNames = dayLabels(dm);
  const showToast = useToast();
  const { profile: activeProfile } = useActiveProfile();
  const defaultFamilyMemberId = activeProfile.isOwnerMode ? null : activeProfile.memberId;

  const { data: familyMembers } = useCachedResource("family-members", (token) => listFamilyMembers(token));

  const [step, setStep] = useState<Step>("who");
  const [familyMemberId, setFamilyMemberId] = useState<string | null>(defaultFamilyMemberId);
  const [showNoFamilyMembers, setShowNoFamilyMembers] = useState(false);

  const selectedFamilyMember = (familyMembers ?? []).find((m) => m.id === familyMemberId) ?? null;

  const { data: records } = useCachedResource(
    `records-for-medication-select-${familyMemberId ?? "self"}`,
    (token) => listRecords(token, { family_member_id: familyMemberId ?? undefined })
  );
  const [source, setSource] = useState<"manual" | "document">("manual");

  const [selectedRecordId, setSelectedRecordId] = useState<string | null>(null);
  const [recordMedications, setRecordMedications] = useState<Record<string, unknown>[]>([]);
  const [loadingRecordMeds, setLoadingRecordMeds] = useState(false);
  const [medicationRequestId, setMedicationRequestId] = useState<string | null>(null);

  const [medicationName, setMedicationName] = useState("");
  const [dosage, setDosage] = useState("");
  const [form, setForm] = useState("");
  const [instructions, setInstructions] = useState("");

  const [frequencyType, setFrequencyType] = useState<MedicationFrequencyType>("daily");
  const [daysOfWeek, setDaysOfWeek] = useState<number[]>([0, 1, 2, 3, 4, 5, 6]);
  const [intervalDays, setIntervalDays] = useState(2);
  const [timesOfDay, setTimesOfDay] = useState<string[]>(["09:00"]);
  const [startDate, setStartDate] = useState(() => new Date().toISOString().slice(0, 10));
  const [endDate, setEndDate] = useState("");
  const [emailEnabled, setEmailEnabled] = useState(true);
  const [pushEnabled, setPushEnabled] = useState(true);

  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const documentsSorted = useMemo(
    () => (records ?? []).slice().sort((a, b) => (a.uploaded_at < b.uploaded_at ? 1 : -1)),
    [records]
  );

  // While the user is on the "member" step itself, familyMemberId is still null (nothing picked
  // yet), so the family-path flag has to also treat being on that step as being on the family
  // path, otherwise the step count would briefly undercount by one while it is showing.
  const isFamilyPath = step === "member" || familyMemberId !== null;
  const pathSteps = useMemo(() => stepsForPath(isFamilyPath, source), [isFamilyPath, source]);
  const stepIndex = Math.max(1, pathSteps.indexOf(step) + 1);
  const totalSteps = pathSteps.length;

  function goBack() {
    setError("");
    if (step === "member") {
      setStep("who");
      return;
    }
    if (step === "source") {
      setStep(familyMemberId === null ? "who" : "member");
      return;
    }
    if (step === "document") {
      if (selectedRecordId) {
        setSelectedRecordId(null);
        return;
      }
      setStep("source");
      return;
    }
    if (step === "details") {
      setStep(source === "document" ? "document" : "source");
      return;
    }
    if (step === "schedule") {
      setStep("details");
      return;
    }
  }

  async function handleSelectDocument(recordId: string) {
    setSelectedRecordId(recordId);
    setLoadingRecordMeds(true);
    setError("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      const full = await getRecordFull(token, recordId);
      setRecordMedications(full.clinical?.medications ?? []);
    } catch {
      setError(dm.medications.add.loadMedicationsError);
    } finally {
      setLoadingRecordMeds(false);
    }
  }

  function handlePickExtractedMedication(med: Record<string, unknown>) {
    setMedicationRequestId(String(med.id));
    setMedicationName(String(med.medication_name_raw ?? ""));
    setDosage(med.dose_quantity ? String(med.dose_quantity) : "");
    setInstructions(med.dosage_instruction ? String(med.dosage_instruction) : "");
    if (med.start_date) setStartDate(String(med.start_date));
    if (med.end_date) setEndDate(String(med.end_date));
    setStep("details");
  }

  function toggleDay(day: number) {
    setDaysOfWeek((prev) => (prev.includes(day) ? prev.filter((d) => d !== day) : [...prev, day].sort()));
  }

  function updateTime(index: number, value: string) {
    setTimesOfDay((prev) => prev.map((t, i) => (i === index ? value : t)));
  }

  function addTime() {
    setTimesOfDay((prev) => [...prev, "09:00"]);
  }

  function removeTime(index: number) {
    setTimesOfDay((prev) => prev.filter((_, i) => i !== index));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (medicationName.trim().length < 1) {
      setError(dm.medications.add.nameRequired);
      return;
    }
    if (frequencyType !== "as_needed" && timesOfDay.length === 0) {
      setError(dm.medications.add.timeRequired);
      return;
    }
    if (frequencyType === "specific_days" && daysOfWeek.length === 0) {
      setError(dm.medications.add.dayRequired);
      return;
    }
    setError("");
    setSubmitting(true);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      const timezone = Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
      await createMedicationReminder(token, {
        family_member_id: familyMemberId,
        source,
        medication_request_id: source === "document" ? medicationRequestId : undefined,
        source_record_id: source === "document" ? selectedRecordId : undefined,
        medication_name: medicationName.trim(),
        dosage: dosage.trim() || undefined,
        form: form.trim() || undefined,
        instructions: instructions.trim() || undefined,
        frequency_type: frequencyType,
        days_of_week: frequencyType === "specific_days" ? daysOfWeek : undefined,
        interval_days: frequencyType === "interval" ? intervalDays : undefined,
        times_of_day: frequencyType === "as_needed" ? [] : timesOfDay,
        timezone,
        start_date: startDate,
        end_date: endDate || undefined,
        email_reminders_enabled: emailEnabled,
        push_reminders_enabled: pushEnabled,
      });
      const savedName = medicationName.trim();
      onClose();
      showToast({
        message: selectedFamilyMember
          ? `${savedName} has been added for ${selectedFamilyMember.full_name}`
          : `${savedName} has been added`,
        variant: "success",
      });
      onCreated();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.medications.add.saveError);
      setSubmitting(false);
    }
  }

  return (
    <div className="flex max-h-[85vh] flex-col">
      <div className="flex items-start justify-between gap-4 border-b border-border px-6 py-5">
        <div className="flex items-start gap-3">
          {step !== "who" && (
            <button
              type="button"
              onClick={goBack}
              aria-label={dm.medications.add.backStep}
              className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-ink-muted hover:bg-surface hover:text-ink max-lg:h-11 max-lg:w-11"
            >
              <ArrowLeft size={18} />
            </button>
          )}
          <div>
            <h2 id="add-medication-title" className="text-base font-semibold text-ink">
              {dm.medications.add.title}
            </h2>
            <p className="mt-0.5 text-sm text-ink-muted">{dm.medications.add.description}</p>
          </div>
        </div>
        <button
          type="button"
          onClick={onClose}
          aria-label={dm.common.close}
          className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-ink max-lg:h-11 max-lg:w-11"
        >
          <X size={18} />
        </button>
      </div>

      <div className="px-6 pt-4">
        <OnboardingProgress step={stepIndex} total={totalSteps} />
      </div>

      <div className="flex-1 overflow-y-auto px-6 pb-6">
        {error && <p className="mb-4 text-sm text-error">{error}</p>}

        {step === "who" && (
          <div className="flex flex-col gap-3">
            <p className="text-sm font-semibold text-ink">{dm.medications.add.whoFor}</p>
            <button
              type="button"
              onClick={() => {
                setFamilyMemberId(null);
                setShowNoFamilyMembers(false);
                setStep("source");
              }}
              className="flex items-center gap-4 rounded-xl border border-border bg-card p-4 text-start hover:border-primary"
            >
              <User size={24} className="text-primary" />
              <div>
                <p className="text-sm font-semibold text-ink">
                  {dm.medications.add.myself}{" "}
                  {defaultFamilyMemberId === null && (
                    <span className="font-normal text-ink-muted">· {dm.medications.add.currentlySelected}</span>
                  )}
                </p>
                <p className="text-xs text-ink-muted">{dm.medications.add.myselfHint}</p>
              </div>
            </button>
            <button
              type="button"
              onClick={() => {
                if ((familyMembers ?? []).length === 0) {
                  setShowNoFamilyMembers(true);
                  return;
                }
                setShowNoFamilyMembers(false);
                setStep("member");
              }}
              className="flex items-center gap-4 rounded-xl border border-border bg-card p-4 text-start hover:border-primary"
            >
              <UsersThree size={24} className="text-primary" />
              <div>
                <p className="text-sm font-semibold text-ink">{dm.medications.familyMember}</p>
                <p className="text-xs text-ink-muted">{dm.medications.add.familyMemberHint}</p>
              </div>
            </button>
            {showNoFamilyMembers && (
              <div className="rounded-xl border border-border bg-surface p-4">
                <p className="text-sm text-ink-muted">{dm.medications.add.noFamilyMembers}</p>
                <Link
                  href="/dashboard/family/add"
                  className="mt-2 inline-block text-sm font-semibold text-primary hover:underline"
                >
                  {dm.family.addMember}
                </Link>
              </div>
            )}
          </div>
        )}

        {step === "member" && (
          <div className="flex flex-col gap-3">
            <p className="text-sm font-semibold text-ink">{dm.medications.add.selectFamilyMember}</p>
            {(familyMembers ?? []).map((m) => (
              <button
                key={m.id}
                type="button"
                onClick={() => {
                  setFamilyMemberId(m.id);
                  setStep("source");
                }}
                className={`flex items-center gap-3 rounded-xl border p-4 text-start hover:border-primary ${
                  familyMemberId === m.id ? "border-primary bg-primary-tint/40" : "border-border bg-card"
                }`}
              >
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary-tint text-sm font-semibold text-primary">
                  {m.full_name.charAt(0)}
                </span>
                <div>
                  <p className="text-sm font-semibold text-ink">{m.full_name}</p>
                  <p className="text-xs capitalize text-ink-muted">
                    {m.relationship}
                    {defaultFamilyMemberId === m.id && ` · ${dm.medications.add.currentlySelected}`}
                  </p>
                </div>
              </button>
            ))}
          </div>
        )}

        {step === "source" && (
          <div className="flex flex-col gap-3">
            {selectedFamilyMember && (
              <p className="text-xs font-medium text-ink-muted">
                {formatMessage(dm.medications.detail.forWhom, { name: selectedFamilyMember.full_name })}
              </p>
            )}
            <p className="text-sm font-semibold text-ink">{dm.medications.add.howToAdd}</p>
            <button
              type="button"
              onClick={() => {
                setSource("document");
                setStep("document");
              }}
              className="flex items-center gap-4 rounded-xl border border-border bg-card p-4 text-start hover:border-primary"
            >
              <FileText size={24} className="text-primary" />
              <div>
                <p className="text-sm font-semibold text-ink">{dm.medications.add.fromDocument}</p>
                <p className="text-xs text-ink-muted">{dm.medications.add.fromDocumentHint}</p>
              </div>
            </button>
            <button
              type="button"
              onClick={() => {
                setSource("manual");
                setMedicationRequestId(null);
                setSelectedRecordId(null);
                setStep("details");
              }}
              className="flex items-center gap-4 rounded-xl border border-border bg-card p-4 text-start hover:border-primary"
            >
              <PencilSimple size={24} className="text-primary" />
              <div>
                <p className="text-sm font-semibold text-ink">{dm.medications.add.manual}</p>
                <p className="text-xs text-ink-muted">{dm.medications.add.manualHint}</p>
              </div>
            </button>
          </div>
        )}

        {step === "document" && (
          <div className="flex flex-col gap-4">
            {!selectedRecordId && (
              <>
                <p className="text-sm font-semibold text-ink">{dm.medications.add.selectDocument}</p>
                {(documentsSorted ?? []).length === 0 && (
                  <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-border bg-card px-6 py-8 text-center">
                    <span className="flex h-12 w-12 items-center justify-center rounded-full bg-info/15 text-info">
                      <UploadSimple size={22} weight="bold" />
                    </span>
                    <p className="max-w-[220px] text-sm text-ink-muted">{dm.medications.add.noDocuments}</p>
                    <Link
                      href="/dashboard/upload"
                      className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
                    >
                      {dm.home.uploadDocument}
                    </Link>
                  </div>
                )}
                <div className="flex flex-col gap-2">
                  {documentsSorted.map((r) => (
                    <button
                      key={r.id}
                      type="button"
                      onClick={() => handleSelectDocument(r.id)}
                      className="flex items-center justify-between rounded-xl border border-border bg-card p-4 text-start hover:border-primary"
                    >
                      <div>
                        <p className="text-sm font-medium text-ink">{r.title}</p>
                        <p className="text-xs text-ink-muted">{new Date(r.uploaded_at).toLocaleDateString()}</p>
                      </div>
                    </button>
                  ))}
                </div>
              </>
            )}

            {selectedRecordId && (
              <>
                <p className="text-sm font-semibold text-ink">{dm.medications.add.selectMedication}</p>
                {loadingRecordMeds && <p className="text-sm text-ink-muted">{dm.medications.add.loadingExtracted}</p>}
                {!loadingRecordMeds && recordMedications.length === 0 && (
                  <p className="text-sm text-ink-muted">{dm.medications.add.noExtracted}</p>
                )}
                <div className="flex flex-col gap-2">
                  {recordMedications.map((med, i) => (
                    <button
                      key={String(med.id ?? i)}
                      type="button"
                      onClick={() => handlePickExtractedMedication(med)}
                      className="rounded-xl border border-border bg-card p-4 text-start hover:border-primary"
                    >
                      <p className="text-sm font-semibold text-ink">
                        {String(med.medication_name_raw ?? dm.medications.add.unknown)}
                      </p>
                      <p className="text-xs text-ink-muted">
                        {[med.dose_quantity, med.dose_frequency].filter(Boolean).join(" · ") ||
                          dm.medications.add.noDosageDetails}
                      </p>
                    </button>
                  ))}
                </div>
              </>
            )}
          </div>
        )}

        {step === "details" && (
          <div className="flex flex-col gap-5">
            <div>
              <label className="block text-sm font-medium text-ink">{dm.medications.add.nameLabel}</label>
              <input
                value={medicationName}
                onChange={(e) => setMedicationName(e.target.value)}
                className={INPUT_CLS}
              />
            </div>
            <div className="grid gap-6 sm:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-ink">{dm.medications.add.dosageLabel}</label>
                <input
                  value={dosage}
                  onChange={(e) => setDosage(e.target.value)}
                  placeholder={dm.medications.add.dosagePlaceholder}
                  className={INPUT_CLS}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-ink">{dm.medications.add.formLabel}</label>
                <input
                  value={form}
                  onChange={(e) => setForm(e.target.value)}
                  placeholder={dm.medications.add.formPlaceholder}
                  className={INPUT_CLS}
                />
              </div>
            </div>
            <div>
              <label className="block text-sm font-medium text-ink">{dm.medications.add.instructionsLabel}</label>
              <textarea
                value={instructions}
                onChange={(e) => setInstructions(e.target.value)}
                placeholder={dm.medications.add.instructionsPlaceholder}
                rows={2}
                className={INPUT_CLS}
              />
            </div>
            <button
              type="button"
              onClick={() => setStep("schedule")}
              disabled={medicationName.trim().length < 1}
              className="self-start rounded-xl bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
            >
              {dm.medications.add.continueToSchedule}
            </button>
          </div>
        )}

        {step === "schedule" && (
          <form onSubmit={handleSubmit} className="flex flex-col gap-6" noValidate>
            <div>
              <label className="block text-sm font-medium text-ink">{dm.medications.add.frequencyLabel}</label>
              <Select
                value={frequencyType}
                onChange={(v) => setFrequencyType(v as MedicationFrequencyType)}
                options={[
                  { value: "daily", label: dm.medications.add.frequencyDaily },
                  { value: "specific_days", label: dm.medications.add.frequencySpecificDays },
                  { value: "interval", label: dm.medications.add.frequencyInterval },
                  { value: "as_needed", label: dm.medications.add.frequencyAsNeeded },
                ]}
                className="mt-1.5"
              />
            </div>

            {frequencyType === "specific_days" && (
              <div className="flex flex-wrap gap-2">
                {dayNames.map((label, i) => (
                  <button
                    key={label}
                    type="button"
                    onClick={() => toggleDay(i)}
                    className={`rounded-full px-3.5 py-1.5 text-sm font-medium ${
                      daysOfWeek.includes(i) ? "bg-primary text-primary-foreground" : "bg-surface text-ink-muted"
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            )}

            {frequencyType === "interval" && (
              <div>
                <label className="block text-sm font-medium text-ink">{dm.medications.add.intervalLabel}</label>
                <input
                  type="number"
                  min={1}
                  max={90}
                  value={intervalDays}
                  onChange={(e) => setIntervalDays(Number(e.target.value))}
                  className={INPUT_CLS}
                />
              </div>
            )}

            {frequencyType !== "as_needed" && (
              <div>
                <label className="block text-sm font-medium text-ink">{dm.medications.add.reminderTimes}</label>
                <div className="mt-1.5 flex flex-col gap-2">
                  {timesOfDay.map((t, i) => (
                    <div key={i} className="flex items-center gap-2">
                      <input
                        type="time"
                        value={t}
                        onChange={(e) => updateTime(i, e.target.value)}
                        className="w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                      />
                      {timesOfDay.length > 1 && (
                        <button
                          type="button"
                          onClick={() => removeTime(i)}
                          className="text-ink-muted hover:text-error"
                        >
                          <X size={18} />
                        </button>
                      )}
                    </div>
                  ))}
                  <button
                    type="button"
                    onClick={addTime}
                    className="flex items-center gap-1.5 self-start text-sm font-medium text-primary hover:underline"
                  >
                    <Plus size={16} /> {dm.medications.add.addAnotherTime}
                  </button>
                </div>
              </div>
            )}

            <div className="grid gap-6 sm:grid-cols-2">
              <div>
                <label className="block text-sm font-medium text-ink">{dm.medications.add.startDate}</label>
                <input
                  type="date"
                  value={startDate}
                  onChange={(e) => setStartDate(e.target.value)}
                  className={INPUT_CLS}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-ink">{dm.medications.add.endDate}</label>
                <input
                  type="date"
                  value={endDate}
                  onChange={(e) => setEndDate(e.target.value)}
                  className={INPUT_CLS}
                />
              </div>
            </div>

            <div className="flex flex-col gap-2 rounded-xl border border-border bg-card p-4">
              <p className="text-sm font-medium text-ink">{dm.medications.add.channels}</p>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input type="checkbox" checked={emailEnabled} onChange={(e) => setEmailEnabled(e.target.checked)} />
                {dm.medications.add.emailChannel}
              </label>
              <label className="flex items-center gap-2 text-sm text-ink-muted">
                <input type="checkbox" checked={pushEnabled} onChange={(e) => setPushEnabled(e.target.checked)} />
                {dm.medications.add.pushChannel}
              </label>
            </div>

            <button
              type="submit"
              disabled={submitting}
              className="rounded-xl bg-primary px-5 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
            >
              {submitting ? dm.common.saving : dm.medications.add.submit}
            </button>
          </form>
        )}
      </div>
    </div>
  );
}

export function AddMedicationModal({
  open,
  onClose,
  onCreated,
}: {
  open: boolean;
  onClose: () => void;
  onCreated: () => void;
}) {
  useEffect(() => {
    if (!open) return;
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") onClose();
    }
    document.addEventListener("keydown", handleKeyDown);
    const { overflow } = document.body.style;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = overflow;
    };
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="add-medication-title"
        className="w-full max-w-2xl overflow-hidden rounded-2xl border border-border bg-card shadow-lg"
      >
        <AddMedicationModalContent onClose={onClose} onCreated={onCreated} />
      </div>
    </div>
  );
}
