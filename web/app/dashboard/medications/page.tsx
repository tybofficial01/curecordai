"use client";

import { useEffect, useMemo, useState } from "react";
import { useSearchParams, useRouter } from "next/navigation";
import type { Icon } from "@phosphor-icons/react";
import {
  Pill,
  Plus,
  Clock,
  CheckCircle,
  Info,
  X,
  UserCircle,
  ClipboardText,
  Warning,
  FileText,
  PencilSimple,
  Trash,
  Bell,
} from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { useConfirm } from "@/lib/dialog/ConfirmDialogProvider";
import { dayLabels, formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";
import {
  listMedicationReminders,
  listUpcomingDoses,
  setDoseStatus,
  deleteMedicationReminder,
} from "@/lib/api/medications";
import { listFamilyMembers } from "@/lib/api/family";
import { ApiError } from "@/lib/api/client";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { AddMedicationModal } from "./AddMedicationModal";
import { EditMedicationModal } from "./EditMedicationModal";
import type { FamilyMember, MedicationReminder, MedicationReminderStatus, UpcomingDose } from "@/lib/api/types";

function frequencySummary(dm: DashboardMessages, m: MedicationReminder): string {
  if (m.frequency_type === "as_needed") return dm.medications.asNeeded;
  const times = (m.times_of_day ?? []).length;
  const timesLabel = formatMessage(dm.medications.timesPerDay, { count: times });
  if (m.frequency_type === "daily") return `${dm.medications.daily} · ${timesLabel}`;
  if (m.frequency_type === "interval") {
    return `${formatMessage(dm.medications.everyNDays, { days: m.interval_days ?? 0 })} · ${timesLabel}`;
  }
  if (m.frequency_type === "specific_days" && m.days_of_week) {
    const labels = dayLabels(dm);
    return `${m.days_of_week.map((d) => labels[d]).join(", ")} · ${timesLabel}`;
  }
  return timesLabel;
}

function formatDoseTime(scheduledAt: string): string {
  return new Date(scheduledAt).toLocaleString([], {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

const MEDICATIONS_HOW_IT_WORKS_ITEMS: { icon: Icon; title: string; description: string }[] = [
  {
    icon: UserCircle,
    title: "Who it is for",
    description: "Medications can be added for yourself or for a family member you manage.",
  },
  {
    icon: ClipboardText,
    title: "Add manually or import",
    description: "Enter details yourself, or pull them from an already uploaded document.",
  },
  {
    icon: CheckCircle,
    title: "Track status",
    description: "Medications can be marked Active, Paused, or Completed using the tabs above.",
  },
];

function MedicationsHowItWorksModal({
  open,
  onClose,
  dm,
}: {
  open: boolean;
  onClose: () => void;
  dm: DashboardMessages;
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
        aria-labelledby="medications-how-it-works-title"
        className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-border bg-card p-6 shadow-lg"
      >
        <div className="flex items-start justify-between gap-4">
          <h2 id="medications-how-it-works-title" className="text-base font-semibold text-ink">
            How Medications Work
          </h2>
          <button
            type="button"
            onClick={onClose}
            aria-label={dm.common.close}
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-ink max-lg:h-11 max-lg:w-11"
          >
            <X size={16} />
          </button>
        </div>

        <div className="mt-4 grid gap-3 sm:grid-cols-2">
          {MEDICATIONS_HOW_IT_WORKS_ITEMS.map((item) => (
            <div key={item.title} className="flex flex-col gap-2 rounded-xl border border-border bg-surface p-4">
              <span className="flex h-9 w-9 items-center justify-center rounded-full bg-primary-tint text-primary">
                <item.icon size={18} />
              </span>
              <p className="text-sm font-semibold text-ink">{item.title}</p>
              <p className="text-xs leading-relaxed text-ink-muted">{item.description}</p>
            </div>
          ))}
        </div>

        <div className="mt-6 flex justify-end">
          <button
            type="button"
            onClick={onClose}
            className="rounded-full bg-primary px-6 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            {dm.common.gotIt}
          </button>
        </div>
      </div>
    </div>
  );
}

// In owner mode this is a shared, family-wide tracking view that aggregates the owner and
// every family member, grouped below. When viewing a specific family member's own profile
// (scopeId set), it is scoped to just that member's medications instead.
async function loadMedications(token: string, scopeId: string | null) {
  if (scopeId) {
    const reminders = await listMedicationReminders(token, { family_member_id: scopeId });
    return { reminders, familyMembers: [] as FamilyMember[] };
  }
  const [ownReminders, familyMembers] = await Promise.all([
    listMedicationReminders(token, {}),
    listFamilyMembers(token),
  ]);
  const memberReminderLists = await Promise.all(
    familyMembers.map((m) => listMedicationReminders(token, { family_member_id: m.id }))
  );
  return { reminders: [...ownReminders, ...memberReminderLists.flat()], familyMembers };
}

export default function MedicationsPage() {
  const dm = useDashboardMessages();
  const router = useRouter();
  const searchParams = useSearchParams();
  const { getAccessToken } = useAuth();
  const confirm = useConfirm();
  const { profile: activeProfile } = useActiveProfile();
  const scopeId = activeProfile.isOwnerMode ? null : activeProfile.memberId;
  const { data, isLoading, error, refetch, setData } = useCachedResource(`medications-${scopeId ?? "self"}`, (token) =>
    loadMedications(token, scopeId)
  );
  const reminders = data?.reminders ?? null;
  const hasAnyMedications = (reminders?.length ?? 0) > 0;
  const familyMembers = data?.familyMembers;
  const [statusTab, setStatusTab] = useState<MedicationReminderStatus | "all">("active");
  const [howItWorksOpen, setHowItWorksOpen] = useState(false);
  const [editingReminder, setEditingReminder] = useState<MedicationReminder | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [rowError, setRowError] = useState("");
  // Supports landing here directly with ?add=1 (e.g. from a link that used to point at the old
  // /dashboard/medications/add page) by opening the same modal instead of a separate route.
  const [addOpen, setAddOpen] = useState(() => searchParams.get("add") === "1");

  useEffect(() => {
    if (searchParams.get("add") === "1") {
      router.replace("/dashboard/medications");
    }
  }, [searchParams, router]);

  // Upcoming doses are tracked separately from the reminder's own Active/Paused/Completed
  // status (see DoseLog in lib/api/types.ts), which is what lets a single dose be marked taken
  // without changing the medication's overall status.
  const { data: upcomingDoses, refetch: refetchDoses } = useCachedResource(
    `upcoming-doses-${scopeId ?? "self"}`,
    (token) => listUpcomingDoses(token, scopeId ? { family_member_id: scopeId } : undefined)
  );

  const nextDoseByReminder = useMemo(() => {
    const map = new Map<string, UpcomingDose>();
    for (const dose of upcomingDoses ?? []) {
      const existing = map.get(dose.reminder_id);
      if (!existing || new Date(dose.scheduled_at) < new Date(existing.scheduled_at)) {
        map.set(dose.reminder_id, dose);
      }
    }
    return map;
  }, [upcomingDoses]);

  const memberById = useMemo(() => {
    const map = new Map<string, FamilyMember>();
    for (const m of familyMembers ?? []) map.set(m.id, m);
    return map;
  }, [familyMembers]);

  async function handleMarkTaken(dose: UpcomingDose) {
    setBusyId(dose.reminder_id);
    setRowError("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      await setDoseStatus(token, dose.reminder_id, { status: "taken", scheduled_at: dose.scheduled_at });
      refetchDoses();
    } catch (err) {
      setRowError(err instanceof ApiError ? err.message : dm.medications.detail.updateError);
    } finally {
      setBusyId(null);
    }
  }

  async function handleDelete(reminder: MedicationReminder) {
    const confirmed = await confirm({
      title: dm.medications.detail.deleteConfirmTitle,
      description: dm.medications.detail.deleteConfirmDescription,
      confirmLabel: dm.common.delete,
      cancelLabel: dm.common.cancel,
      destructive: true,
    });
    if (!confirmed) return;
    setBusyId(reminder.id);
    setRowError("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      await deleteMedicationReminder(token, reminder.id);
      setData((prev) => (prev ? { ...prev, reminders: prev.reminders.filter((r) => r.id !== reminder.id) } : prev));
    } catch (err) {
      setRowError(err instanceof ApiError ? err.message : dm.medications.detail.deleteError);
    } finally {
      setBusyId(null);
    }
  }

  const filtered = (reminders ?? []).filter((r) => statusTab === "all" || r.status === statusTab);

  // Used only for the tab-specific empty state's short note (e.g. "3 Completed in other
  // tabs"), so someone landing on an empty Active tab knows their medications still exist
  // rather than assuming they were lost.
  const otherStatusesWithCounts = useMemo(() => {
    const counts: Record<MedicationReminderStatus, number> = { active: 0, paused: 0, completed: 0 };
    for (const r of reminders ?? []) counts[r.status]++;
    return (["active", "paused", "completed"] as const)
      .filter((s) => s !== statusTab && counts[s] > 0)
      .map((status) => ({ status, count: counts[status] }));
  }, [reminders, statusTab]);

  const grouped = useMemo(() => {
    const groups = new Map<string, { label: string; items: MedicationReminder[] }>();
    for (const r of filtered) {
      const key = r.family_member_id ?? "self";
      const label = r.family_member_id
        ? memberById.get(r.family_member_id)?.full_name ?? activeProfile.memberName ?? dm.medications.familyMember
        : dm.medications.you;
      if (!groups.has(key)) groups.set(key, { label, items: [] });
      groups.get(key)!.items.push(r);
    }
    return Array.from(groups.values());
  }, [filtered, memberById, dm, activeProfile.memberName]);

  return (
    <div>
      {/* Inlined rather than using the shared PageHeading component, which stacks the action
          below the title on narrow screens - that left the info icon floating alone in empty
          space under the description on mobile. Keeping the row unconditional (no flex-col
          fallback) puts the icons directly next to the heading at every width, matching the
          desktop layout and the same fix applied to the AI Health Assistant page. */}
      <div className="mb-8 flex items-start justify-between gap-4 sm:items-center">
        <div>
          <h1 className="text-2xl font-bold text-ink sm:text-3xl">{dm.medications.title}</h1>
          <p className="mt-1 text-sm text-ink-muted">{dm.medications.description}</p>
        </div>
        {/* Wraps instead of forcing one line so a present Add Medication button drops to its own
            row on narrow screens rather than squeezing the title, while the info icon still
            stays on the same line as the heading either way. */}
        <div className="flex flex-wrap shrink-0 items-center justify-end gap-2">
          <button
            type="button"
            onClick={() => setHowItWorksOpen(true)}
            aria-label="How medications work"
            title="How medications work"
            className="flex h-9 w-9 items-center justify-center rounded-full text-ink-muted transition-colors hover:bg-primary-tint hover:text-primary"
          >
            <Info size={20} />
          </button>
          {hasAnyMedications && (
            <button
              type="button"
              onClick={() => setAddOpen(true)}
              className="inline-flex items-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
            >
              <Plus size={18} weight="bold" />
              {dm.medications.addMedication}
            </button>
          )}
        </div>
      </div>

      <MedicationsHowItWorksModal open={howItWorksOpen} onClose={() => setHowItWorksOpen(false)} dm={dm} />
      <AddMedicationModal open={addOpen} onClose={() => setAddOpen(false)} onCreated={refetch} />
      <EditMedicationModal
        reminder={editingReminder}
        onClose={() => setEditingReminder(null)}
        onUpdated={(updated) =>
          setData((prev) =>
            prev
              ? { ...prev, reminders: prev.reminders.map((r) => (r.id === updated.id ? updated : r)) }
              : prev
          )
        }
      />
      {rowError && <p className="mb-4 text-sm text-error">{rowError}</p>}

      <div className="mb-6 flex gap-2">
        {(["active", "paused", "completed", "all"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setStatusTab(tab)}
            className={`rounded-full px-4 py-1.5 text-sm font-medium ${
              statusTab === tab ? "bg-primary text-primary-foreground" : "bg-surface text-ink-muted hover:text-ink"
            }`}
          >
            {dm.medications.tabs[tab]}
          </button>
        ))}
      </div>

      {isLoading && (
        <div className="flex flex-col gap-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-24" />
          ))}
        </div>
      )}
      {error && <p className="text-sm text-error">{error}</p>}

      {reminders && filtered.length === 0 && !hasAnyMedications && (
        <>
          <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-border bg-card px-6 py-10 text-center">
            <span className="flex h-14 w-14 items-center justify-center rounded-full bg-primary-tint text-primary">
              <Pill size={28} weight="duotone" />
            </span>
            <h2 className="text-lg font-semibold text-ink">{dm.medications.emptyTitle}</h2>
            <p className="max-w-sm text-sm text-ink-muted">{dm.medications.emptyDescription}</p>
            <button
              type="button"
              onClick={() => setAddOpen(true)}
              className="mt-1 inline-flex items-center gap-2 rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
            >
              <Plus size={18} weight="bold" />
              {dm.medications.addMedication}
            </button>
          </div>

          <div className="mt-6 grid gap-3 sm:grid-cols-2">
            <div className="rounded-2xl border border-border bg-card p-4">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-warning/15 text-warning">
                <Warning size={20} weight="bold" />
              </span>
              <p className="mt-3.5 text-sm font-bold text-ink">Checked against your allergies</p>
              <p className="mt-0.5 text-xs text-ink-muted">
                Medications you track show up alongside your recorded allergies in your AI health summary, making it
                easier for you and your care team to notice a potential conflict.
              </p>
            </div>
            <div className="rounded-2xl border border-border bg-card p-4">
              <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-info/15 text-info">
                <FileText size={20} weight="bold" />
              </span>
              <p className="mt-3.5 text-sm font-bold text-ink">Consistent with your documents</p>
              <p className="mt-0.5 text-xs text-ink-muted">
                Importing a medication from an uploaded prescription links it to that document, so your medication
                list stays consistent with the rest of your health records.
              </p>
            </div>
          </div>
        </>
      )}

      {reminders && filtered.length === 0 && hasAnyMedications && statusTab !== "all" && (
        <div className="rounded-2xl border border-dashed border-border bg-card px-6 py-6 text-center">
          <p className="text-sm font-medium text-ink-muted">
            No {dm.medications.tabs[statusTab].toLowerCase()} medications
          </p>
          {otherStatusesWithCounts.length > 0 && (
            <p className="mt-1 text-xs text-ink-faint">
              You have {otherStatusesWithCounts.map((s) => `${s.count} ${dm.medications.tabs[s.status]}`).join(", ")}{" "}
              in other tabs.
            </p>
          )}
        </div>
      )}

      {reminders && filtered.length > 0 && (
        <div className="flex flex-col gap-8">
          {grouped.map((group) => (
            <div key={group.label}>
              <h2 className="mb-3 border-b border-border pb-2 text-base font-bold text-ink">{group.label}</h2>
              <div className="flex flex-col gap-3">
                {group.items.map((m) => {
                  const nextDose = m.status === "active" ? nextDoseByReminder.get(m.id) : undefined;
                  const doseActionable =
                    nextDose && (nextDose.dose_status === "pending" || nextDose.dose_status === "sent");
                  const isPaused = m.status === "paused";
                  const isCompleted = m.status === "completed";
                  return (
                    <div
                      key={m.id}
                      role="button"
                      tabIndex={0}
                      onClick={() => router.push(`/dashboard/medications/${m.id}`)}
                      onKeyDown={(event) => {
                        if (event.key === "Enter" || event.key === " ") {
                          event.preventDefault();
                          router.push(`/dashboard/medications/${m.id}`);
                        }
                      }}
                      className={`flex cursor-pointer items-center gap-4 rounded-2xl border border-border bg-card p-5 transition-colors hover:border-primary ${
                        isPaused ? "opacity-60" : ""
                      }`}
                    >
                      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary-tint text-primary">
                        <Pill size={20} weight="fill" />
                      </span>
                      <div className="min-w-0 flex-1">
                        <p
                          className={`truncate text-sm font-semibold text-ink ${
                            isCompleted ? "text-ink-muted line-through" : ""
                          }`}
                        >
                          {m.medication_name}
                        </p>
                        <p className="mt-0.5 flex items-center gap-1.5 text-xs text-ink-muted">
                          <Clock size={14} />
                          {frequencySummary(dm, m)}
                          {(m.times_of_day ?? []).length > 0 && ` (${m.times_of_day.join(", ")})`}
                        </p>
                        <p className="mt-1 text-xs text-ink-muted">
                          {dm.medications.detail.dosage}: {m.dosage ?? "Not provided"} · {dm.medications.detail.form}:{" "}
                          {m.form ?? "Not provided"}
                        </p>
                        {nextDose && (
                          <p className="mt-1 flex items-center gap-1.5 text-xs text-primary">
                            <Bell size={13} />
                            Next dose {formatDoseTime(nextDose.scheduled_at)}
                          </p>
                        )}
                      </div>
                      <div className="flex shrink-0 flex-col items-end gap-2">
                        {m.status === "active" && (
                          <span className="flex items-center gap-1 rounded-full bg-success/10 px-2.5 py-1 text-xs font-medium text-success">
                            <CheckCircle size={14} weight="fill" /> {dm.medications.activeChip}
                          </span>
                        )}
                        {isCompleted && (
                          <span className="flex items-center gap-1 rounded-full bg-ink-faint/10 px-2.5 py-1 text-xs font-medium text-ink-muted">
                            <CheckCircle size={14} weight="fill" /> {dm.medications.tabs.completed}
                          </span>
                        )}
                        {isPaused && (
                          <span className="rounded-full bg-surface px-2.5 py-1 text-xs font-medium text-ink-muted">
                            {dm.medications.tabs.paused}
                          </span>
                        )}
                        <div className="flex items-center gap-3">
                          {doseActionable && nextDose && (
                            <button
                              type="button"
                              disabled={busyId === m.id}
                              onClick={(event) => {
                                event.stopPropagation();
                                handleMarkTaken(nextDose);
                              }}
                              className="text-xs font-medium text-primary hover:underline disabled:opacity-50"
                            >
                              Mark as taken
                            </button>
                          )}
                          <button
                            type="button"
                            onClick={(event) => {
                              event.stopPropagation();
                              setEditingReminder(m);
                            }}
                            aria-label={`${dm.common.edit} ${m.medication_name}`}
                            className="flex items-center justify-center max-lg:p-2.5 text-ink-muted hover:text-primary"
                          >
                            <PencilSimple size={16} />
                          </button>
                          <button
                            type="button"
                            disabled={busyId === m.id}
                            onClick={(event) => {
                              event.stopPropagation();
                              handleDelete(m);
                            }}
                            aria-label={`${dm.common.remove} ${m.medication_name}`}
                            className="flex items-center justify-center max-lg:p-2.5 text-ink-muted hover:text-error disabled:opacity-50"
                          >
                            <Trash size={16} />
                          </button>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
