"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { Icon } from "@phosphor-icons/react";
import {
  FolderSimple,
  UploadSimple,
  ChatCircleDots,
  QrCode,
  FileText,
  Warning,
  ChatCircleText,
  CaretRight,
  Pill,
  Scan,
  Flask,
  X,
} from "@phosphor-icons/react/dist/ssr";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { getProfile } from "@/lib/api/profile";
import { listRecords } from "@/lib/api/records";
import { listChatSessions } from "@/lib/api/aiChat";
import { getHealthSummary } from "@/lib/api/insights";
import { listAllergies } from "@/lib/api/allergies";
import { listDoctorInstructions } from "@/lib/api/sharing";
import { listMedicationReminders } from "@/lib/api/medications";
import type { RecordType } from "@/lib/api/types";
import { computeProfileCompletionPct } from "@/lib/profileCompletion";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";

async function loadDashboard(token: string, familyMemberId?: string | null) {
  const scopeId = familyMemberId ?? undefined;
  const [profile, sessions, summary, allergies, records, instructions, medications] = await Promise.all([
    getProfile(token),
    listChatSessions(token, scopeId),
    getHealthSummary(token, scopeId),
    listAllergies(token, { clinical_status: "active", family_member_id: scopeId }),
    listRecords(token, { family_member_id: scopeId }),
    listDoctorInstructions(token, scopeId),
    listMedicationReminders(token, { family_member_id: scopeId, status: "active" }),
  ]);
  records.sort((a, b) => new Date(b.uploaded_at).getTime() - new Date(a.uploaded_at).getTime());
  return { profile, records, sessions, summary, allergies, instructions, medications };
}

interface DocumentCategorySegment {
  key: RecordType | "other";
  label: string;
  count: number;
  barClass: string;
  dotClass: string;
}

function getDocumentCategorySegments(records: { record_type: RecordType }[]): DocumentCategorySegment[] {
  const counts = records.reduce<Record<string, number>>((acc, record) => {
    acc[record.record_type] = (acc[record.record_type] ?? 0) + 1;
    return acc;
  }, {});

  const namedTypes: { key: RecordType; label: string; barClass: string; dotClass: string }[] = [
    { key: "prescription", label: "Prescriptions", barClass: "bg-info", dotClass: "bg-info" },
    { key: "radiology", label: "Radiology", barClass: "bg-warning", dotClass: "bg-warning" },
    { key: "lab_report", label: "Lab reports", barClass: "bg-success", dotClass: "bg-success" },
  ];

  const segments: DocumentCategorySegment[] = namedTypes.map((type) => ({
    ...type,
    count: counts[type.key] ?? 0,
  }));

  const namedCount = segments.reduce((sum, segment) => sum + segment.count, 0);
  const otherCount = records.length - namedCount;
  if (otherCount > 0) {
    segments.push({ key: "other", label: "Other", count: otherCount, barClass: "bg-ink-faint/40", dotClass: "bg-ink-faint" });
  }

  return segments;
}

const DOCUMENT_TYPE_VISUALS: Partial<Record<RecordType, { icon: Icon; tint: string }>> = {
  prescription: { icon: Pill, tint: "bg-info/15 text-info" },
  radiology: { icon: Scan, tint: "bg-warning/15 text-warning" },
  lab_report: { icon: Flask, tint: "bg-success/15 text-success" },
};
const DEFAULT_DOCUMENT_TYPE_VISUAL = { icon: FolderSimple, tint: "bg-primary-tint text-primary" };

function formatCompactRelativeTime(date: Date, now: Date): string {
  const diffMinutes = Math.max(0, Math.round((now.getTime() - date.getTime()) / 60000));
  if (diffMinutes < 1) return "just now";
  if (diffMinutes < 60) return `${diffMinutes}m`;
  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) return `${diffHours}h`;
  const diffDays = Math.round(diffHours / 24);
  if (diffDays < 7) return `${diffDays}d`;
  if (diffDays < 30) return `${Math.round(diffDays / 7)}w`;
  const diffMonths = Math.round(diffDays / 30);
  if (diffMonths < 12) return `${diffMonths}mo`;
  return `${Math.round(diffMonths / 12)}y`;
}

function isWithinHours(dateString: string, hours: number, now: Date): boolean {
  const diffMs = now.getTime() - new Date(dateString).getTime();
  return diffMs >= 0 && diffMs <= hours * 60 * 60 * 1000;
}

function NewTag() {
  return (
    <span className="shrink-0 rounded-full bg-success/15 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-success">
      New
    </span>
  );
}

function DashboardEmptyState({
  icon: IconComponent,
  tint,
  description,
  actionHref,
  actionLabel,
}: {
  icon: Icon;
  tint: string;
  description: string;
  actionHref: string;
  actionLabel: string;
}) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-border bg-card px-6 py-10 text-center">
      <span className={`flex h-12 w-12 items-center justify-center rounded-full ${tint}`}>
        <IconComponent size={22} weight="bold" />
      </span>
      <p className="max-w-[220px] text-sm text-ink-muted">{description}</p>
      <Link
        href={actionHref}
        className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
      >
        {actionLabel}
      </Link>
    </div>
  );
}

function formatRelativeTime(date: Date, now: Date): string {
  const diffMinutes = Math.max(0, Math.round((now.getTime() - date.getTime()) / 60000));
  if (diffMinutes < 60) return diffMinutes <= 1 ? "1 minute" : `${diffMinutes} minutes`;
  const diffHours = Math.round(diffMinutes / 60);
  if (diffHours < 24) return diffHours === 1 ? "1 hour" : `${diffHours} hours`;
  const diffDays = Math.round(diffHours / 24);
  if (diffDays < 30) return diffDays === 1 ? "1 day" : `${diffDays} days`;
  const diffMonths = Math.round(diffDays / 30);
  if (diffMonths < 12) return diffMonths === 1 ? "1 month" : `${diffMonths} months`;
  const diffYears = Math.round(diffMonths / 12);
  return diffYears === 1 ? "1 year" : `${diffYears} years`;
}

interface DashboardNudge {
  id: string;
  message: string;
  buttonLabel: string;
  href: string;
}

function getDashboardNudge(
  input: {
    hasUnreadDoctorInstruction: boolean;
    documentsUploaded: number;
    activeMedications: number;
  },
  dm: DashboardMessages
): DashboardNudge | null {
  if (input.hasUnreadDoctorInstruction) {
    return {
      id: "unread-doctor-instruction",
      message: dm.home.nudgeUnreadInstructionMessage,
      buttonLabel: dm.home.nudgeUnreadInstructionButton,
      href: "/dashboard/share",
    };
  }
  if (input.documentsUploaded === 0) {
    return {
      id: "no-documents",
      message: dm.home.nudgeNoDocumentsMessage,
      buttonLabel: dm.home.nudgeNoDocumentsButton,
      href: "/dashboard/upload",
    };
  }
  if (input.activeMedications === 0) {
    return {
      id: "no-medications",
      message: dm.home.nudgeNoMedicationsMessage,
      buttonLabel: dm.home.nudgeNoMedicationsButton,
      href: "/dashboard/medications/add",
    };
  }
  return null;
}

function getTimeBasedGreeting(date: Date, dm: DashboardMessages): string {
  const hour = date.getHours();
  if (hour < 12) return dm.home.greetingMorning;
  if (hour < 17) return dm.home.greetingAfternoon;
  if (hour < 21) return dm.home.greetingEvening;
  return dm.home.greetingNight;
}

const ROTATING_TIPS_ID = "rotating-tips";

function useRotatingMessage(messages: string[], enabled: boolean, intervalMs = 9000, fadeMs = 300) {
  const [index, setIndex] = useState(0);
  const [fading, setFading] = useState(false);
  const [reducedMotion, setReducedMotion] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia) return;
    const query = window.matchMedia("(prefers-reduced-motion: reduce)");
    setReducedMotion(query.matches);
    const handleChange = (event: MediaQueryListEvent) => setReducedMotion(event.matches);
    query.addEventListener("change", handleChange);
    return () => query.removeEventListener("change", handleChange);
  }, []);

  useEffect(() => {
    if (!enabled || reducedMotion || messages.length <= 1) return;
    let fadeTimeout: ReturnType<typeof setTimeout>;
    const interval = setInterval(() => {
      setFading(true);
      fadeTimeout = setTimeout(() => {
        setIndex((prev) => (prev + 1) % messages.length);
        setFading(false);
      }, fadeMs);
    }, intervalMs);
    return () => {
      clearInterval(interval);
      clearTimeout(fadeTimeout);
    };
  }, [enabled, reducedMotion, messages.length, intervalMs, fadeMs]);

  return { message: messages[index], fading: reducedMotion ? false : fading };
}

function ProfileCompletionRing({ percent }: { percent: number }) {
  const size = 56;
  const stroke = 5;
  const radius = (size - stroke) / 2;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference * (1 - percent / 100);

  return (
    <div className="relative flex h-14 w-14 shrink-0 items-center justify-center">
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke="rgba(255,255,255,0.25)" strokeWidth={stroke} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke="white"
          strokeWidth={stroke}
          strokeDasharray={circumference}
          strokeDashoffset={offset}
          strokeLinecap="round"
        />
      </svg>
      <span className="absolute text-[11px] font-extrabold text-primary-foreground">{percent}%</span>
    </div>
  );
}

export default function DashboardHomePage() {
  const { profile: activeProfile } = useActiveProfile();
  const dm = useDashboardMessages();
  const [dismissedIds, setDismissedIds] = useState<Set<string>>(() => new Set());
  const [greeting, setGreeting] = useState(dm.home.greetingMorning);
  useEffect(() => {
    setGreeting(getTimeBasedGreeting(new Date(), dm));
  }, [dm]);
  const scopeId = activeProfile.isOwnerMode ? null : activeProfile.memberId;
  const { data, isLoading, error } = useCachedResource(`dashboard-${scopeId ?? "self"}`, (token) =>
    loadDashboard(token, scopeId)
  );

  // Derived the same way as the profile screen (see lib/profileCompletion.ts) rather than
  // trusting the persisted profile_completion_pct column, which only gets recalculated by a
  // handful of save endpoints and can drift out of sync with the profile's actual field state.
  const completionPct = data
    ? computeProfileCompletionPct({
        fullName: data.profile.full_name,
        dob: data.profile.date_of_birth,
        gender: data.profile.gender,
        bloodGroup: data.profile.blood_group,
        height: data.profile.height_cm,
        weight: data.profile.weight_kg,
        avatarUrl: data.profile.profile_photo_url,
      })
    : 0;
  const hasUnreadDoctorInstruction = data ? data.instructions.some((instruction) => !instruction.seen_at) : false;
  const priorityNudge = data
    ? getDashboardNudge(
        {
          hasUnreadDoctorInstruction,
          documentsUploaded: data.records.length,
          activeMedications: data.summary.active_medications,
        },
        dm
      )
    : null;
  const visiblePriorityNudge = priorityNudge && !dismissedIds.has(priorityNudge.id) ? priorityNudge : null;
  const showProfileRing = !!data && activeProfile.isOwnerMode && completionPct < 100;
  const showRotatingFallback = !!data && !visiblePriorityNudge && !dismissedIds.has(ROTATING_TIPS_ID);
  const { message: rotatingMessage, fading: rotatingFading } = useRotatingMessage(
    dm.home.rotatingTips,
    showRotatingFallback
  );
  const subtitle = activeProfile.isOwnerMode
    ? dm.home.subtitleOwner
    : formatMessage(dm.home.subtitleMember, { name: activeProfile.memberName ?? "" });

  if (isLoading) return <DashboardHomeSkeleton />;
  if (error || !data) return <p className="text-sm text-error">{error ?? dm.home.loadError}</p>;

  const { profile, records, sessions, summary, allergies, medications } = data;

  const documentCategorySegments = getDocumentCategorySegments(records);
  const mostRecentMedicationUpdate = medications.reduce<Date | null>((latest, medication) => {
    const updatedAt = new Date(medication.updated_at);
    return !latest || updatedAt > latest ? updatedAt : latest;
  }, null);
  const medicationsReviewedLabel = mostRecentMedicationUpdate
    ? formatRelativeTime(mostRecentMedicationUpdate, new Date())
    : null;

  const quickActions = [
    {
      href: "/dashboard/upload",
      label: dm.home.uploadDocument,
      subtitle: dm.home.uploadDocumentSubtitle,
      icon: UploadSimple,
      accent: "bg-primary/15 text-primary",
    },
    {
      href: "/dashboard/assistant",
      label: dm.home.askAi,
      subtitle: dm.home.askAiSubtitle,
      icon: ChatCircleDots,
      accent: "bg-success/15 text-success",
    },
    {
      href: "/dashboard/share",
      label: dm.home.shareWithDoctor,
      subtitle: dm.home.shareWithDoctorSubtitle,
      icon: QrCode,
      accent: "bg-info/15 text-info",
    },
    {
      href: "/dashboard/summary",
      label: dm.home.viewSummary,
      subtitle: dm.home.viewSummarySubtitle,
      icon: FileText,
      accent: "bg-ink-faint/15 text-ink-muted",
    },
  ];

  const recentDocuments = records.slice(0, 3);
  const recentConversations = sessions.slice(0, 3);
  const allergyNames = allergies.map((a) => a.substance_name).filter(Boolean);
  const now = new Date();

  return (
    <div>
      <div
        className="relative mb-8 overflow-hidden rounded-[28px] bg-primary bg-cover bg-top px-6 py-6 sm:px-8 sm:py-7"
        style={{ backgroundImage: "url(/dashboard/header-texture.png)" }}
      >
        <div className="pointer-events-none absolute -right-8 -top-12 z-0 h-44 w-44 rounded-full bg-white/[0.05]" />
        <div className="pointer-events-none absolute -bottom-20 right-10 z-0 h-60 w-60 rounded-full bg-white/[0.04]" />
        <div className="pointer-events-none absolute bottom-3 right-24 z-0 h-16 w-16 rounded-full bg-white/[0.06]" />

        <div className="relative z-10 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div className="min-w-0 flex-1">
            <p className="text-sm font-medium text-primary-foreground/80">{greeting} 👋</p>
            <p className="mt-1 text-2xl font-extrabold text-primary-foreground sm:text-[27px]">
              {activeProfile.isOwnerMode ? profile.full_name.trim().split(" ")[0] : activeProfile.memberName}
            </p>
            <p className="mt-1.5 text-sm text-primary-foreground/80">{subtitle}</p>

            {visiblePriorityNudge && (
              <div className="relative mt-4 rounded-2xl border border-white/[0.08] bg-white/[0.06] px-4 py-3 pe-9 backdrop-blur-sm">
                <button
                  type="button"
                  onClick={() => setDismissedIds((prev) => new Set(prev).add(visiblePriorityNudge.id))}
                  aria-label={dm.home.dismiss}
                  className="absolute end-2 top-2 flex h-6 w-6 items-center justify-center rounded-full text-primary-foreground/70 hover:bg-white/10 hover:text-primary-foreground"
                >
                  <X size={14} weight="bold" />
                </button>
                <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between sm:gap-3">
                  <p className="text-sm font-medium text-primary-foreground">{visiblePriorityNudge.message}</p>
                  <Link
                    href={visiblePriorityNudge.href}
                    className="inline-flex w-fit shrink-0 items-center rounded-full bg-white px-4 py-1.5 text-xs font-bold text-primary hover:bg-white/90"
                  >
                    {visiblePriorityNudge.buttonLabel}
                  </Link>
                </div>
              </div>
            )}

            {showRotatingFallback && (
              <div className="relative mt-4 rounded-2xl border border-white/[0.08] bg-white/[0.06] px-4 py-3 pe-9 backdrop-blur-sm">
                <button
                  type="button"
                  onClick={() => setDismissedIds((prev) => new Set(prev).add(ROTATING_TIPS_ID))}
                  aria-label={dm.home.dismiss}
                  className="absolute end-2 top-2 flex h-6 w-6 items-center justify-center rounded-full text-primary-foreground/70 hover:bg-white/10 hover:text-primary-foreground"
                >
                  <X size={14} weight="bold" />
                </button>
                <p
                  className={`text-sm font-medium text-primary-foreground transition-opacity duration-300 ${
                    rotatingFading ? "opacity-0" : "opacity-100"
                  }`}
                >
                  {rotatingMessage}
                </p>
              </div>
            )}
          </div>

          {showProfileRing && (
            <div className="flex shrink-0 items-center gap-4 pe-1 sm:self-center sm:pe-2">
              <ProfileCompletionRing percent={completionPct} />
              <div>
                <p className="text-sm font-semibold text-primary-foreground">{dm.home.completeProfile}</p>
                <Link
                  href="/dashboard/profile"
                  className="mt-1.5 inline-flex items-center rounded-full border border-white/60 bg-white/[0.08] px-4 py-1.5 text-xs font-bold text-primary-foreground hover:bg-white/20"
                >
                  {dm.home.completeProfileButton}
                </Link>
              </div>
            </div>
          )}
        </div>
      </div>

      {allergyNames.length > 0 && (
        <Link
          href="/dashboard/summary"
          className="mb-6 flex items-center gap-3.5 rounded-2xl border border-border border-s-4 border-s-error bg-card p-4 transition-colors hover:bg-error/[0.03]"
        >
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-error/[0.12] text-error">
            <Warning size={20} weight="bold" />
          </span>
          <div className="min-w-0 flex-1">
            <p className="text-sm font-semibold text-ink">{dm.home.activeAllergies}</p>
            <p className="mt-0.5 truncate text-xs text-ink-muted">{allergyNames.join(", ")}</p>
          </div>
          <span className="shrink-0 rounded-full border border-border px-3.5 py-1.5 text-xs font-semibold text-ink">
            {dm.home.viewDetails}
          </span>
        </Link>
      )}

      <div className="grid gap-4 sm:grid-cols-2">
        <Link
          href="/dashboard/vault"
          className="relative rounded-2xl border border-border bg-card p-5 transition-colors hover:border-primary"
        >
          <CaretRight size={16} className="absolute end-5 top-5 text-ink-faint rtl:-scale-x-100" />
          <p className="text-sm font-semibold text-ink-muted">{dm.home.totalDocuments}</p>
          <p className="mt-1.5 flex items-end gap-2">
            <span className="text-4xl font-extrabold leading-none text-primary">{records.length}</span>
            <span className="pb-1 text-sm text-ink-muted">{dm.home.uploadedLabel}</span>
          </p>

          {records.length > 0 ? (
            <>
              <div className="mt-4 flex h-1.5 w-full overflow-hidden rounded-full bg-border">
                {documentCategorySegments.map(
                  (segment) =>
                    segment.count > 0 && (
                      <span
                        key={segment.key}
                        className={`h-full ${segment.barClass}`}
                        style={{ width: `${(segment.count / records.length) * 100}%` }}
                      />
                    )
                )}
              </div>
              <div className="mt-3 flex flex-wrap gap-x-4 gap-y-1.5">
                {documentCategorySegments
                  .filter((segment) => segment.count > 0)
                  .map((segment) => (
                    <span key={segment.key} className="flex items-center gap-1.5 text-xs text-ink-muted">
                      <span className={`h-2 w-2 rounded-full ${segment.dotClass}`} />
                      {segment.count} {segment.label}
                    </span>
                  ))}
              </div>
            </>
          ) : (
            <div className="mt-3 flex items-start gap-2 rounded-lg border border-info/25 bg-info/[0.08] px-3 py-2.5 text-xs leading-relaxed text-info">
              <UploadSimple size={14} weight="bold" className="mt-0.5 shrink-0" />
              {dm.home.nudgeNoDocumentsMessage}
            </div>
          )}
        </Link>

        <Link
          href="/dashboard/medications"
          className="relative rounded-2xl border border-border bg-card p-5 transition-colors hover:border-primary"
        >
          <CaretRight size={16} className="absolute end-5 top-5 text-ink-faint rtl:-scale-x-100" />
          <p className="text-sm font-semibold text-ink-muted">{dm.home.medications}</p>
          <p className="mt-1.5 flex items-end gap-2">
            <span className="text-4xl font-extrabold leading-none text-primary">{summary.active_medications}</span>
            <span className="pb-1 text-sm text-ink-muted">{dm.home.activeLabel}</span>
          </p>

          {summary.active_medications === 0 ? (
            <>
              <p className="mt-1 text-xs text-ink-faint">{dm.home.noMedicationsYet}</p>
              <div className="mt-3 flex items-start gap-2 rounded-lg bg-warning-bg px-3 py-2.5 text-xs leading-relaxed text-warning-dark">
                <Warning size={14} weight="fill" className="mt-0.5 shrink-0" />
                {dm.home.addMedicationsHint}
              </div>
            </>
          ) : (
            medicationsReviewedLabel && (
              <p className="mt-1 text-xs text-ink-faint">Reviewed {medicationsReviewedLabel} ago</p>
            )
          )}
        </Link>
      </div>

      <div className="mt-6 grid grid-cols-2 gap-3 lg:grid-cols-4">
        {quickActions.map((action) => (
          <Link
            key={action.href}
            href={action.href}
            className="rounded-2xl border border-border bg-card p-3.5 transition-colors hover:border-primary hover:bg-primary-tint/40 sm:p-4"
          >
            <span className={`flex h-10 w-10 items-center justify-center rounded-xl sm:h-11 sm:w-11 ${action.accent}`}>
              <action.icon size={20} weight="bold" />
            </span>
            <p className="mt-3.5 text-sm font-bold text-ink">{action.label}</p>
            <p className="mt-0.5 text-xs text-ink-muted">{action.subtitle}</p>
          </Link>
        ))}
      </div>

      <div className="mt-10 grid grid-cols-1 gap-8 lg:grid-cols-2">
        <div>
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-ink">{dm.home.recentDocuments}</h2>
            <Link href="/dashboard/vault" className="text-sm font-medium text-primary hover:underline">
              {dm.common.viewAll}
            </Link>
          </div>
          <div className="mt-4 flex flex-col gap-3">
            {recentDocuments.length === 0 && (
              <DashboardEmptyState
                icon={UploadSimple}
                tint="bg-info/15 text-info"
                description={dm.home.noDocuments}
                actionHref="/dashboard/upload"
                actionLabel={dm.home.uploadDocument}
              />
            )}
            {recentDocuments.map((doc) => {
              const { icon: DocIcon, tint } = DOCUMENT_TYPE_VISUALS[doc.record_type] ?? DEFAULT_DOCUMENT_TYPE_VISUAL;
              return (
                <Link
                  key={doc.id}
                  href={`/dashboard/vault/${doc.id}`}
                  className="flex items-center gap-3 rounded-xl border border-border bg-card p-4 hover:border-primary"
                >
                  <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${tint}`}>
                    <DocIcon size={18} weight="bold" />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <p className="truncate text-sm font-semibold text-ink">{doc.title}</p>
                      {isWithinHours(doc.uploaded_at, 48, now) && <NewTag />}
                    </div>
                    <p className="text-xs text-ink-muted capitalize">
                      {dm.recordTypes[doc.record_type] ?? doc.record_type.replace(/_/g, " ")} &middot;{" "}
                      {dm.recordStatus[doc.processing_status] ?? doc.processing_status}
                    </p>
                  </div>
                  <span className="shrink-0 text-xs text-ink-faint">
                    {formatCompactRelativeTime(new Date(doc.uploaded_at), now)} ago
                  </span>
                </Link>
              );
            })}
          </div>
        </div>

        <div>
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-semibold text-ink">{dm.home.recentConversations}</h2>
            <Link href="/dashboard/assistant" className="text-sm font-medium text-primary hover:underline">
              {dm.home.openAssistant}
            </Link>
          </div>
          <div className="mt-4 flex flex-col gap-3">
            {recentConversations.length === 0 && (
              <DashboardEmptyState
                icon={ChatCircleDots}
                tint="bg-success/15 text-success"
                description={dm.home.noConversations}
                actionHref="/dashboard/assistant"
                actionLabel={dm.home.askAi}
              />
            )}
            {recentConversations.map((conv) => (
              <Link
                key={conv.id}
                href={`/dashboard/assistant?conversation=${conv.id}`}
                className="flex items-center gap-3 rounded-xl border border-border border-s-4 border-s-info bg-card p-4 hover:border-primary hover:border-s-info"
              >
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-info/15 text-info">
                  <ChatCircleText size={18} />
                </span>
                <div className="min-w-0 flex-1">
                  <div className="flex items-center gap-2">
                    <p className="truncate text-sm font-semibold text-ink">{conv.title ?? dm.home.newConversation}</p>
                    {isWithinHours(conv.updated_at, 48, now) && <NewTag />}
                  </div>
                  <p className="text-xs text-ink-muted">
                    {formatMessage(dm.home.messagesCount, { count: conv.total_messages })} &middot;{" "}
                    {formatRelativeTime(new Date(conv.updated_at), now)} ago
                  </p>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function DashboardHomeSkeleton() {
  return (
    <div>
      <Skeleton className="mb-8 h-32 rounded-[28px]" />
      <div className="grid gap-4 sm:grid-cols-2">
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
      </div>
      <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        {Array.from({ length: 4 }).map((_, i) => (
          <Skeleton key={i} className="h-28" />
        ))}
      </div>
      <div className="mt-10 grid grid-cols-1 gap-8 lg:grid-cols-2">
        {Array.from({ length: 2 }).map((_, col) => (
          <div key={col} className="flex flex-col gap-3">
            <Skeleton className="h-5 w-40" />
            {Array.from({ length: 3 }).map((_, i) => (
              <Skeleton key={i} className="h-16" />
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
