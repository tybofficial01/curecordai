"use client";

import { useState, type ReactNode } from "react";
import { useParams, useRouter } from "next/navigation";
import Link from "next/link";
import { ArrowLeft, Pause, Play, CheckCircle, Trash, PencilSimple } from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useConfirm } from "@/lib/dialog/ConfirmDialogProvider";
import { listFamilyMembers } from "@/lib/api/family";
import {
  getMedicationReminder,
  updateMedicationReminder,
  deleteMedicationReminder,
} from "@/lib/api/medications";
import { ApiError } from "@/lib/api/client";
import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { EditMedicationModal } from "../EditMedicationModal";
import type { MedicationReminderStatus } from "@/lib/api/types";

const NOT_PROVIDED = "Not provided";

export default function MedicationDetailPage() {
  const { id } = useParams<{ id: string }>();
  const { getAccessToken } = useAuth();
  const router = useRouter();
  const confirm = useConfirm();
  const dm = useDashboardMessages();

  const { data: reminder, isLoading, setData } = useCachedResource(`medication-${id}`, (token) =>
    getMedicationReminder(token, id)
  );
  const { data: familyMembers } = useCachedResource("family-members", (token) => listFamilyMembers(token));
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);
  const [editOpen, setEditOpen] = useState(false);

  const memberName = reminder?.family_member_id
    ? familyMembers?.find((m) => m.id === reminder.family_member_id)?.full_name
    : dm.medications.you;

  async function changeStatus(status: MedicationReminderStatus) {
    if (!reminder) return;
    setBusy(true);
    setError("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      const updated = await updateMedicationReminder(token, reminder.id, { status });
      setData(updated);
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.medications.detail.updateError);
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete() {
    if (!reminder) return;
    const confirmed = await confirm({
      title: dm.medications.detail.deleteConfirmTitle,
      description: dm.medications.detail.deleteConfirmDescription,
      confirmLabel: dm.common.delete,
      cancelLabel: dm.common.cancel,
      destructive: true,
    });
    if (!confirmed) return;
    setBusy(true);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      await deleteMedicationReminder(token, reminder.id);
      router.push("/dashboard/medications");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.medications.detail.deleteError);
      setBusy(false);
    }
  }

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="flex items-center justify-between gap-4">
        <Link
          href="/dashboard/medications"
          className="flex items-center gap-2 text-sm font-medium text-ink-muted hover:text-primary"
        >
          <ArrowLeft size={16} /> {dm.medications.add.back}
        </Link>
        {reminder && (
          <button
            type="button"
            onClick={() => setEditOpen(true)}
            className="flex items-center gap-2 max-lg:py-2.5 text-sm font-medium text-ink-muted hover:text-primary"
          >
            <PencilSimple size={16} /> {dm.common.edit}
          </button>
        )}
      </div>

      {isLoading && <Skeleton className="mt-6 h-48" />}
      {error && <p className="mt-4 text-sm text-error">{error}</p>}

      {reminder && (
        <>
          <PageHeading
            title={reminder.medication_name}
            description={formatMessage(dm.medications.detail.forWhom, { name: memberName ?? "" })}
          />

          <EditMedicationModal
            reminder={editOpen ? reminder : null}
            onClose={() => setEditOpen(false)}
            onUpdated={(updated) => setData(updated)}
          />

          <div className="flex items-center justify-between rounded-2xl border border-border bg-card p-5">
            <span className="text-sm font-medium text-ink-muted">{dm.medications.detail.status}</span>
            <StatusBadge status={reminder.status} label={dm.medications.tabs[reminder.status]} />
          </div>

          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            <Section title="Medication details">
              <Row label={dm.medications.detail.dosage} value={reminder.dosage ?? NOT_PROVIDED} />
              <Row label={dm.medications.detail.form} value={reminder.form ?? NOT_PROVIDED} />
              <Row label={dm.medications.detail.instructions} value={reminder.instructions ?? NOT_PROVIDED} />
            </Section>

            <Section title="Schedule">
              <Row label={dm.medications.detail.frequency} value={frequencyTypeLabel(dm, reminder.frequency_type)} />
              <Row
                label={dm.medications.detail.times}
                value={(reminder.times_of_day ?? []).join(", ") || NOT_PROVIDED}
              />
              <Row label={dm.medications.detail.startDate} value={reminder.start_date} />
              <Row label={dm.medications.detail.endDate} value={reminder.end_date ?? dm.medications.detail.ongoing} />
              <Row label={dm.medications.detail.timezone} value={reminder.timezone} />
            </Section>
          </div>

          <div className="mt-6">
            <Section title="Notifications">
              <Row
                label={dm.medications.detail.reminders}
                value={
                  [
                    reminder.email_reminders_enabled ? dm.medications.detail.email : null,
                    reminder.push_reminders_enabled ? dm.medications.detail.mobileAlarm : null,
                  ]
                    .filter(Boolean)
                    .join(" · ") || dm.common.none
                }
              />
            </Section>
          </div>

          <div className="mt-6 flex flex-wrap gap-3">
            {reminder.status !== "active" && (
              <button
                disabled={busy}
                onClick={() => changeStatus("active")}
                className="flex items-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
              >
                <Play size={16} /> {dm.medications.detail.resume}
              </button>
            )}
            {reminder.status === "active" && (
              <button
                disabled={busy}
                onClick={() => changeStatus("paused")}
                className="flex items-center gap-2 rounded-xl border border-border bg-transparent px-4 py-2.5 text-sm font-semibold text-ink hover:bg-surface disabled:opacity-50"
              >
                <Pause size={16} /> {dm.medications.detail.pause}
              </button>
            )}
            {reminder.status !== "completed" && (
              <button
                disabled={busy}
                onClick={() => changeStatus("completed")}
                className="flex items-center gap-2 rounded-xl bg-success px-4 py-2.5 text-sm font-semibold text-white hover:opacity-90 disabled:opacity-50"
              >
                <CheckCircle size={16} weight="fill" /> {dm.medications.detail.markCompleted}
              </button>
            )}
            <button
              disabled={busy}
              onClick={handleDelete}
              className="flex items-center gap-2 rounded-xl bg-error-bg px-4 py-2.5 text-sm font-semibold text-error hover:opacity-90 disabled:opacity-50"
            >
              <Trash size={16} /> {dm.common.delete}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

// The frequency type is a backend enum, so it needs its own mapping rather than the
// old `.replace("_", " ")` cosmetic fix-up, which only ever produced English.
function frequencyTypeLabel(
  dm: ReturnType<typeof useDashboardMessages>,
  frequencyType: string
): string {
  const add = dm.medications.add;
  if (frequencyType === "daily") return add.frequencyDaily;
  if (frequencyType === "specific_days") return add.frequencySpecificDays;
  if (frequencyType === "interval") return add.frequencyInterval;
  if (frequencyType === "as_needed") return dm.medications.asNeeded;
  return frequencyType;
}

function Section({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-3 rounded-2xl border border-border bg-card p-6">
      <h3 className="text-sm font-semibold uppercase tracking-wide text-ink-muted">{title}</h3>
      <div className="flex flex-col gap-3">{children}</div>
    </div>
  );
}

function StatusBadge({ status, label }: { status: MedicationReminderStatus; label: string }) {
  if (status === "active") {
    return (
      <span className="flex items-center gap-1.5 rounded-full bg-success/10 px-3 py-1 text-sm font-medium text-success">
        <CheckCircle size={14} weight="fill" /> {label}
      </span>
    );
  }
  if (status === "completed") {
    return (
      <span className="flex items-center gap-1.5 rounded-full bg-ink-faint/10 px-3 py-1 text-sm font-medium text-ink-muted">
        <CheckCircle size={14} weight="fill" /> {label}
      </span>
    );
  }
  return (
    <span className="rounded-full bg-surface px-3 py-1 text-sm font-medium text-ink-muted">{label}</span>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-start justify-between gap-4 border-b border-border pb-3 last:border-0 last:pb-0">
      <span className="text-sm text-ink-muted">{label}</span>
      <span
        className={`text-end text-sm font-medium ${value === NOT_PROVIDED ? "text-ink-faint" : "text-ink"}`}
      >
        {value}
      </span>
    </div>
  );
}
