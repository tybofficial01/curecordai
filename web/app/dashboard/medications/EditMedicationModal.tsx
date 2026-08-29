"use client";

import { useEffect, useState, type FormEvent } from "react";
import { Plus, X } from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { updateMedicationReminder } from "@/lib/api/medications";
import { ApiError } from "@/lib/api/client";
import { dayLabels, useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { Select } from "@/components/ui/Select";
import type { MedicationFrequencyType, MedicationReminder } from "@/lib/api/types";

const INPUT_CLS =
  "mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20";

function EditMedicationModalContent({
  reminder,
  onClose,
  onUpdated,
}: {
  reminder: MedicationReminder;
  onClose: () => void;
  onUpdated: (updated: MedicationReminder) => void;
}) {
  const { getAccessToken } = useAuth();
  const dm = useDashboardMessages();
  const dayNames = dayLabels(dm);

  const [medicationName, setMedicationName] = useState(reminder.medication_name);
  const [dosage, setDosage] = useState(reminder.dosage ?? "");
  const [form, setForm] = useState(reminder.form ?? "");
  const [instructions, setInstructions] = useState(reminder.instructions ?? "");
  const [frequencyType, setFrequencyType] = useState<MedicationFrequencyType>(reminder.frequency_type);
  const [daysOfWeek, setDaysOfWeek] = useState<number[]>(reminder.days_of_week ?? [0, 1, 2, 3, 4, 5, 6]);
  const [intervalDays, setIntervalDays] = useState(reminder.interval_days ?? 2);
  const [timesOfDay, setTimesOfDay] = useState<string[]>(
    reminder.times_of_day.length > 0 ? reminder.times_of_day : ["09:00"]
  );
  const [startDate, setStartDate] = useState(reminder.start_date);
  const [endDate, setEndDate] = useState(reminder.end_date ?? "");
  const [emailEnabled, setEmailEnabled] = useState(reminder.email_reminders_enabled);
  const [pushEnabled, setPushEnabled] = useState(reminder.push_reminders_enabled);

  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

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
      const updated = await updateMedicationReminder(token, reminder.id, {
        medication_name: medicationName.trim(),
        dosage: dosage.trim() || undefined,
        form: form.trim() || undefined,
        instructions: instructions.trim() || undefined,
        frequency_type: frequencyType,
        days_of_week: frequencyType === "specific_days" ? daysOfWeek : undefined,
        interval_days: frequencyType === "interval" ? intervalDays : undefined,
        times_of_day: frequencyType === "as_needed" ? [] : timesOfDay,
        timezone: reminder.timezone,
        start_date: startDate,
        end_date: endDate || undefined,
        email_reminders_enabled: emailEnabled,
        push_reminders_enabled: pushEnabled,
      });
      onUpdated(updated);
      onClose();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.medications.detail.updateError);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="flex max-h-[85vh] flex-col">
      <div className="flex items-start justify-between gap-4 border-b border-border px-6 py-5">
        <div>
          <h2 id="edit-medication-title" className="text-base font-semibold text-ink">
            Edit Medication
          </h2>
          <p className="mt-0.5 text-sm text-ink-muted">Update the details for this medication reminder.</p>
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

      <div className="flex-1 overflow-y-auto px-6 py-6">
        {error && <p className="mb-4 text-sm text-error">{error}</p>}

        <form onSubmit={handleSubmit} className="flex flex-col gap-6" noValidate>
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
                      <button type="button" onClick={() => removeTime(i)} className="text-ink-muted hover:text-error">
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
              <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className={INPUT_CLS} />
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
            {submitting ? dm.common.saving : "Save changes"}
          </button>
        </form>
      </div>
    </div>
  );
}

export function EditMedicationModal({
  reminder,
  onClose,
  onUpdated,
}: {
  reminder: MedicationReminder | null;
  onClose: () => void;
  onUpdated: (updated: MedicationReminder) => void;
}) {
  const open = reminder !== null;

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

  if (!open || !reminder) return null;

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
        aria-labelledby="edit-medication-title"
        className="w-full max-w-2xl overflow-hidden rounded-2xl border border-border bg-card shadow-lg"
      >
        <EditMedicationModalContent reminder={reminder} onClose={onClose} onUpdated={onUpdated} />
      </div>
    </div>
  );
}
