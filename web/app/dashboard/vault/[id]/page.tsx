"use client";

import { useEffect, useState, type ReactNode } from "react";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowLeft,
  FolderSimple,
  ChatCircleDots,
  Sparkle,
  DownloadSimple,
  Trash,
  TextT,
  Tag,
  CalendarBlank,
  User,
  Buildings,
  Stethoscope,
  Paperclip,
  CheckCircle,
  Clock,
  WarningCircle,
  Heartbeat,
  Pill,
  WarningOctagon,
  TestTube,
  Hospital,
  PencilSimple,
} from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";
import { useAuth } from "@/lib/auth/AuthContext";
import { useAsyncResource } from "@/lib/hooks/useAsyncResource";
import { useConfirm } from "@/lib/dialog/ConfirmDialogProvider";
import { deleteRecord, getRecordFull, updateRecord } from "@/lib/api/records";
import { ApiError } from "@/lib/api/client";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { DocumentPreviewModal } from "@/components/dashboard/DocumentPreviewModal";

function statusIcon(status: string) {
  if (status === "completed") return CheckCircle;
  if (status === "failed") return WarningCircle;
  return Clock;
}

function statusColorClass(status: string) {
  if (status === "completed") return "text-success";
  if (status === "failed") return "text-error";
  return "text-ink-muted";
}

function formatDetailDate(value: string | null | undefined) {
  if (!value) return " - ";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return " - ";
  return date.toLocaleDateString(undefined, { month: "short", day: "2-digit", year: "numeric" });
}

function capitalise(value: string) {
  if (!value) return value;
  return value[0].toUpperCase() + value.slice(1).replace(/-/g, " ");
}

function interpretationColorClass(interpretation: string) {
  if (interpretation === "H" || interpretation === "HH") return "error";
  if (interpretation === "L" || interpretation === "LL") return "info";
  if (interpretation === "A" || interpretation === "AA") return "warning";
  return "success";
}

function field(record: Record<string, unknown>, key: string): string | null {
  const value = record[key];
  return value === null || value === undefined || value === "" ? null : String(value);
}

function toDateInputValue(value: string | null | undefined) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  return date.toISOString().slice(0, 10);
}

export default function DocumentDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const { getAccessToken } = useAuth();
  const confirm = useConfirm();
  const dm = useDashboardMessages();
  const { data: record, isLoading, error, refetch } = useAsyncResource(
    (token) => getRecordFull(token, params.id),
    [params.id]
  );
  const [isDeleting, setIsDeleting] = useState(false);
  const [deleteError, setDeleteError] = useState("");
  const [isPreviewOpen, setIsPreviewOpen] = useState(false);

  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [saveError, setSaveError] = useState("");
  const [editTitle, setEditTitle] = useState("");
  const [editDate, setEditDate] = useState("");
  const [editPatientName, setEditPatientName] = useState("");
  const [editLabOrg, setEditLabOrg] = useState("");
  const [editDoctor, setEditDoctor] = useState("");

  const isProcessing = record?.processing_status === "pending" || record?.processing_status === "processing";

  useEffect(() => {
    if (!isProcessing) return;
    const interval = setInterval(refetch, 3000);
    return () => clearInterval(interval);
  }, [isProcessing, refetch]);

  function enterEditMode() {
    if (!record) return;
    setEditTitle(record.title);
    setEditDate(toDateInputValue(record.record_date));
    setEditPatientName(record.patient_name_on_doc ?? "");
    setEditLabOrg(record.laboratory_name ?? "");
    setEditDoctor(record.referring_doctor ?? "");
    setSaveError("");
    setIsEditing(true);
  }

  function cancelEditMode() {
    setIsEditing(false);
    setSaveError("");
  }

  async function handleSaveEdit() {
    if (!record) return;
    if (editTitle.trim().length === 0) {
      setSaveError(dm.document.titleEmpty);
      return;
    }
    // Only send fields the user actually changed - mirrors the mobile app's diff-before-save.
    const body: Parameters<typeof updateRecord>[2] = {};
    const trimmedTitle = editTitle.trim();
    if (trimmedTitle !== record.title) body.title = trimmedTitle;
    if (editDate !== toDateInputValue(record.record_date)) body.record_date = editDate || null;
    const trimmedPatient = editPatientName.trim();
    if (trimmedPatient !== (record.patient_name_on_doc ?? "")) body.patient_name_on_doc = trimmedPatient || null;
    const trimmedLabOrg = editLabOrg.trim();
    if (trimmedLabOrg !== (record.laboratory_name ?? "")) body.laboratory_name = trimmedLabOrg || null;
    const trimmedDoctor = editDoctor.trim();
    if (trimmedDoctor !== (record.referring_doctor ?? "")) body.referring_doctor = trimmedDoctor || null;

    if (Object.keys(body).length === 0) {
      setIsEditing(false);
      return;
    }

    setSaveError("");
    setIsSaving(true);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      await updateRecord(token, record.id, body);
      await refetch();
      setIsEditing(false);
    } catch (err) {
      setSaveError(err instanceof ApiError ? err.message : dm.document.saveError);
    } finally {
      setIsSaving(false);
    }
  }

  async function handleDelete() {
    if (!record) return;
    const confirmed = await confirm({
      title: formatMessage(dm.document.deleteConfirmTitle, { title: record.title }),
      description: dm.document.deleteConfirmDescription,
      confirmLabel: dm.common.delete,
      cancelLabel: dm.common.cancel,
      destructive: true,
    });
    if (!confirmed) return;
    setDeleteError("");
    setIsDeleting(true);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.notSignedIn);
      await deleteRecord(token, record.id);
      router.push("/dashboard/vault");
    } catch (err) {
      setDeleteError(err instanceof Error ? err.message : dm.document.deleteError);
      setIsDeleting(false);
    }
  }

  if (isLoading) {
    return (
      <div className="mx-auto max-w-2xl">
        <Skeleton className="h-4 w-40" />
        <div className="mt-4 flex items-center gap-4">
          <Skeleton className="h-14 w-14 rounded-full" />
          <div className="flex-1">
            <Skeleton className="h-6 w-56" />
            <Skeleton className="mt-2 h-4 w-40" />
          </div>
        </div>
        <Skeleton className="mt-8 h-32" />
        <div className="mt-6 grid gap-4 sm:grid-cols-2">
          <Skeleton className="h-24" />
          <Skeleton className="h-24" />
        </div>
      </div>
    );
  }

  if (error || !record) {
    return (
      <div className="mx-auto max-w-lg text-center">
        <h1 className="text-2xl font-bold text-ink">{dm.document.notFoundTitle}</h1>
        <p className="mt-2 text-sm text-ink-muted">{dm.document.notFoundDescription}</p>
        <Link
          href="/dashboard/vault"
          className="mt-6 inline-flex rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
        >
          {dm.document.backToVault}
        </Link>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl">
      <Link href="/dashboard/vault" className="flex items-center gap-2 text-sm font-medium text-ink-muted hover:text-primary">
        <ArrowLeft size={16} /> {dm.document.backToVault}
      </Link>

      <div className="mt-4 flex flex-wrap items-center justify-between gap-4">
        <div className="flex items-center gap-3 sm:gap-4">
          <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary-tint text-primary sm:h-14 sm:w-14">
            <FolderSimple size={22} className="sm:hidden" />
            <FolderSimple size={26} className="hidden sm:block" />
          </span>
          <div>
            <h1 className="text-lg font-bold text-ink sm:text-2xl">{record.title}</h1>
            <p className="text-xs text-ink-muted sm:text-sm">
              {dm.recordTypes[record.record_type] ?? record.record_type} &middot;{" "}
              {formatDetailDate(record.record_date ?? record.uploaded_at)}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-3 sm:gap-4">
          {record.download_url && (
            <button
              type="button"
              onClick={() => setIsPreviewOpen(true)}
              className="flex items-center gap-1.5 max-lg:py-2.5 text-sm font-medium text-ink-muted hover:text-primary"
            >
              <DownloadSimple size={16} /> {dm.document.viewOriginal}
            </button>
          )}
          <button
            type="button"
            onClick={handleDelete}
            disabled={isDeleting}
            className="flex items-center gap-1.5 max-lg:py-2.5 text-sm font-medium text-error hover:underline disabled:opacity-60"
          >
            <Trash size={16} /> {isDeleting ? dm.common.deleting : dm.common.delete}
          </button>
        </div>
      </div>
      {deleteError && <p className="mt-2 text-sm text-error">{deleteError}</p>}

      {record.processing_status === "processing" && (
        <div className="mt-6 flex items-center gap-3 rounded-xl border border-info/25 bg-info/[0.08] px-3.5 py-3">
          <span className="h-4 w-4 shrink-0 animate-spin rounded-full border-2 border-info/30 border-t-info" />
          <p className="text-sm text-info">{dm.document.extracting}</p>
        </div>
      )}
      {record.processing_status === "failed" && (
        <div className="mt-6 flex items-start gap-2.5 rounded-xl border border-error/25 bg-error/[0.08] px-3.5 py-3">
          <WarningCircle size={18} className="mt-px shrink-0 text-error" />
          <p className="text-sm text-error">
            {record.processing_error
              ? formatMessage(dm.document.processingFailedWithReason, { reason: record.processing_error })
              : dm.document.processingFailed}
          </p>
        </div>
      )}

      {record.ai_summary && (
        <div className="mt-6 rounded-[14px] border border-primary/[0.18] bg-primary/[0.04] p-4">
          <div className="flex items-center gap-1.5">
            <Sparkle size={15} className="text-primary" weight="fill" />
            <h2 className="text-[13px] font-bold uppercase tracking-wide text-primary">{dm.document.aiSummary}</h2>
          </div>
          <p className="mt-2.5 whitespace-pre-line text-[13px] leading-[1.6] text-ink-muted">{record.ai_summary}</p>
        </div>
      )}

      <div className="mt-4 flex flex-col gap-2 sm:flex-row">
        {record.ai_analysis && (
          <Link
            href={`/dashboard/vault/${record.id}/summary`}
            className="flex flex-1 items-center justify-center gap-2 rounded-2xl bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            <Sparkle size={18} weight="fill" /> {dm.document.aiSummary}
          </Link>
        )}
        <Link
          href={`/dashboard/assistant?prefill=${encodeURIComponent(
            formatMessage(dm.document.explainPrefill, { title: record.title })
          )}&recordId=${record.id}&recordTitle=${encodeURIComponent(record.title)}`}
          className="flex flex-1 items-center justify-center gap-2 rounded-2xl border border-primary/50 px-6 py-3 text-sm font-semibold text-primary hover:bg-primary-tint"
        >
          <ChatCircleDots size={18} /> {dm.document.explainWithAi}
        </Link>
      </div>

      <div className="mt-8">
        <div className="flex items-center justify-between">
          <h2 className="text-sm font-bold text-ink">{dm.document.detailsTitle}</h2>
          {isEditing ? (
            <button type="button" onClick={cancelEditMode} className="text-xs font-medium text-ink-muted hover:text-ink">
              {dm.common.cancel}
            </button>
          ) : (
            <button
              type="button"
              onClick={enterEditMode}
              className="flex items-center gap-1 max-lg:py-2.5 text-xs font-medium text-primary hover:underline"
            >
              <PencilSimple size={13} /> {dm.common.edit}
            </button>
          )}
        </div>
        <div className="mt-2 divide-y divide-border overflow-hidden rounded-[14px] border border-border bg-card">
          {isEditing ? (
            <EditRow icon={TextT} label={dm.document.fieldTitle} value={editTitle} onChange={setEditTitle} />
          ) : (
            <DetailRow icon={TextT} label={dm.document.fieldTitle} value={record.title} />
          )}
          <DetailRow
            icon={Tag}
            label={dm.document.fieldType}
            value={dm.recordTypes[record.record_type] ?? record.record_type}
          />
          {isEditing ? (
            <EditRow icon={CalendarBlank} label={dm.document.fieldDate} type="date" value={editDate} onChange={setEditDate} />
          ) : (
            <DetailRow icon={CalendarBlank} label={dm.document.fieldDate} value={formatDetailDate(record.record_date)} />
          )}
          {isEditing ? (
            <EditRow icon={User} label={dm.document.fieldPatientName} value={editPatientName} onChange={setEditPatientName} />
          ) : (
            <DetailRow icon={User} label={dm.document.fieldPatientName} value={record.patient_name_on_doc} />
          )}
          {isEditing ? (
            <EditRow icon={Buildings} label={dm.document.fieldLabOrg} value={editLabOrg} onChange={setEditLabOrg} />
          ) : (
            <DetailRow
              icon={Buildings}
              label={dm.document.fieldLabOrg}
              value={record.laboratory_name ?? record.issuing_organization}
            />
          )}
          {isEditing ? (
            <EditRow icon={Stethoscope} label={dm.document.fieldReferringDoctor} value={editDoctor} onChange={setEditDoctor} />
          ) : (
            <DetailRow icon={Stethoscope} label={dm.document.fieldReferringDoctor} value={record.referring_doctor} />
          )}
          <DetailRow icon={Paperclip} label={dm.document.fieldFile} value={record.file_name} />
          <DetailRow
            icon={statusIcon(record.processing_status)}
            label={dm.document.fieldStatus}
            value={dm.documentStatus[record.processing_status] ?? record.processing_status}
            valueClassName={statusColorClass(record.processing_status)}
          />
        </div>
        {saveError && <p className="mt-2 text-sm text-error">{saveError}</p>}
        {isEditing && (
          <div className="mt-3 flex gap-3">
            <button
              type="button"
              onClick={cancelEditMode}
              disabled={isSaving}
              className="flex-1 rounded-full border border-border px-6 py-2.5 text-sm font-semibold text-ink hover:bg-surface disabled:opacity-60"
            >
              {dm.common.cancel}
            </button>
            <button
              type="button"
              onClick={handleSaveEdit}
              disabled={isSaving}
              className="flex-[2] rounded-full bg-primary px-6 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-70"
            >
              {isSaving ? dm.common.saving : dm.common.saveChanges}
            </button>
          </div>
        )}
      </div>

      {record.clinical && (
        <div className="mt-6 flex flex-col gap-4">
          {record.clinical.observations.length > 0 && (
            <ClinicalBlock icon={TestTube} title={dm.document.labResultsAndVitals}>
              {record.clinical.observations.map((obs, index) => (
                <ObservationRow key={index} obs={obs} dm={dm} />
              ))}
            </ClinicalBlock>
          )}
          {record.clinical.conditions.length > 0 && (
            <ClinicalBlock icon={Heartbeat} title={dm.document.conditions}>
              {record.clinical.conditions.map((cond, index) => (
                <ConditionRow key={index} cond={cond} />
              ))}
            </ClinicalBlock>
          )}
          {record.clinical.medications.length > 0 && (
            <ClinicalBlock icon={Pill} title={dm.document.medications}>
              {record.clinical.medications.map((med, index) => (
                <MedicationRow key={index} med={med} dm={dm} />
              ))}
            </ClinicalBlock>
          )}
          {record.clinical.allergies.length > 0 && (
            <ClinicalBlock icon={WarningOctagon} title={dm.document.allergies}>
              {record.clinical.allergies.map((allergy, index) => (
                <AllergyRow key={index} allergy={allergy} />
              ))}
            </ClinicalBlock>
          )}
          {record.clinical.encounters.length > 0 && (
            <ClinicalBlock icon={Hospital} title={dm.document.encounters}>
              {record.clinical.encounters.map((enc, index) => (
                <EncounterRow key={index} enc={enc} dm={dm} />
              ))}
            </ClinicalBlock>
          )}
        </div>
      )}

      {record.download_url && (
        <DocumentPreviewModal
          open={isPreviewOpen}
          onClose={() => setIsPreviewOpen(false)}
          title={record.title}
          url={record.download_url}
          mimeType={record.file_mime_type}
        />
      )}
    </div>
  );
}

function DetailRow({
  icon: RowIcon,
  label,
  value,
  valueClassName,
}: {
  icon: Icon;
  label: string;
  value: string | null | undefined;
  valueClassName?: string;
}) {
  return (
    <div className="flex items-center gap-2.5 px-4 py-3">
      <RowIcon size={16} className="shrink-0 text-ink-faint" />
      <span className="w-[110px] shrink-0 text-[13px] font-medium text-ink-muted">{label}</span>
      <span className={`flex-1 truncate text-end text-[13px] font-medium ${valueClassName ?? "text-ink"}`}>
        {value || " - "}
      </span>
    </div>
  );
}

function EditRow({
  icon: RowIcon,
  label,
  value,
  onChange,
  type = "text",
}: {
  icon: Icon;
  label: string;
  value: string;
  onChange: (value: string) => void;
  type?: "text" | "date";
}) {
  return (
    <div className="flex items-center gap-2.5 px-4 py-2">
      <RowIcon size={16} className="shrink-0 text-primary" />
      <span className="w-[110px] shrink-0 text-[13px] font-medium text-ink-muted">{label}</span>
      <input
        type={type}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="min-w-0 flex-1 rounded-md border border-border bg-background px-2 py-1.5 text-end text-[13px] font-medium text-ink outline-none focus:border-primary focus:ring-1 focus:ring-primary/30"
      />
    </div>
  );
}

function ClinicalBlock({ icon: BlockIcon, title, children }: { icon: Icon; title: string; children: ReactNode }) {
  return (
    <div>
      <div className="flex items-center gap-1.5">
        <BlockIcon size={15} className="text-primary" />
        <p className="text-sm font-bold text-ink">{title}</p>
      </div>
      <div className="mt-2 divide-y divide-border overflow-hidden rounded-[14px] border border-border bg-card">
        {children}
      </div>
    </div>
  );
}

const chipColorClasses: Record<string, string> = {
  error: "bg-error/[0.12] text-error",
  success: "bg-success/[0.12] text-success",
  warning: "bg-warning/[0.12] text-warning",
  info: "bg-info/[0.12] text-info",
};

function StatusChip({ label, color }: { label: string; color: string }) {
  return (
    <span className={`shrink-0 whitespace-nowrap rounded-full px-2.5 py-1 text-[11px] font-semibold ${chipColorClasses[color]}`}>
      {label}
    </span>
  );
}

function ObservationRow({ obs, dm }: { obs: Record<string, unknown>; dm: DashboardMessages }) {
  const name = field(obs, "observation_name") ?? " - ";
  const unit = field(obs, "value_unit") ?? "";
  const qty = field(obs, "value_quantity");
  const value = qty ?? field(obs, "value_string") ?? " - ";
  const displayValue = qty !== null ? `${qty} ${unit}`.trim() : value;
  const refLow = field(obs, "reference_range_low");
  const refHigh = field(obs, "reference_range_high");
  const refRange = refLow !== null && refHigh !== null ? `${refLow}–${refHigh} ${unit}`.trim() : null;
  const interpretation = field(obs, "interpretation");
  const interpLabel = interpretation
    ? dm.document.interpretation[interpretation as keyof DashboardMessages["document"]["interpretation"]]
    : undefined;

  return (
    <div className="flex items-start justify-between gap-3 px-4 py-3">
      <div className="min-w-0">
        <p className="truncate text-[13px] font-semibold text-ink">{name}</p>
        {refRange && (
          <p className="mt-0.5 text-[11px] text-ink-faint">
            {dm.document.referencePrefix} {refRange}
          </p>
        )}
      </div>
      <div className="flex shrink-0 flex-col items-end gap-1">
        <p className="text-[13px] font-semibold text-ink">{displayValue}</p>
        {interpLabel && <StatusChip label={interpLabel} color={interpretationColorClass(interpretation!)} />}
      </div>
    </div>
  );
}

function ConditionRow({ cond }: { cond: Record<string, unknown> }) {
  const dm = useDashboardMessages();
  const name = field(cond, "condition_name") ?? " - ";
  const status = field(cond, "clinical_status");
  const code = field(cond, "icd11_code");

  return (
    <div className="flex items-start justify-between gap-3 px-4 py-3">
      <div className="min-w-0">
        <p className="truncate text-[13px] font-semibold text-ink">{name}</p>
        {code && (
          <p className="mt-0.5 text-[11px] text-ink-faint">{formatMessage(dm.document.icd11Prefix, { code })}</p>
        )}
      </div>
      {status && <StatusChip label={status} color={status === "active" ? "error" : "success"} />}
    </div>
  );
}

function MedicationRow({ med, dm }: { med: Record<string, unknown>; dm: DashboardMessages }) {
  const name = field(med, "medication_name_raw") ?? " - ";
  const dosage = field(med, "dosage_instruction");
  const freq = field(med, "dose_frequency");
  const detail = [dosage, freq].filter(Boolean).join(" · ");
  const hasActiveReminder = med.has_active_reminder === true;

  return (
    <div className="flex items-start justify-between gap-3 px-4 py-3">
      <div className="min-w-0">
        <p className="truncate text-[13px] font-semibold text-ink">{name}</p>
        {detail && <p className="mt-0.5 text-[12px] text-ink-faint">{detail}</p>}
      </div>
      {hasActiveReminder && <StatusChip label={dm.document.activeChip} color="success" />}
    </div>
  );
}

function AllergyRow({ allergy }: { allergy: Record<string, unknown> }) {
  const substance = field(allergy, "substance_name") ?? " - ";
  const criticality = field(allergy, "criticality");
  const reaction = field(allergy, "reaction_description");

  return (
    <div className="flex items-start justify-between gap-3 px-4 py-3">
      <div className="min-w-0">
        <p className="truncate text-[13px] font-semibold text-ink">{substance}</p>
        {reaction && <p className="mt-0.5 text-[12px] text-ink-faint">{reaction}</p>}
      </div>
      {criticality && <StatusChip label={criticality} color={criticality === "high" ? "error" : "warning"} />}
    </div>
  );
}

function EncounterRow({ enc, dm }: { enc: Record<string, unknown>; dm: DashboardMessages }) {
  const type = field(enc, "encounter_type") ?? " - ";
  const practitioner = field(enc, "practitioner_name");
  const org = field(enc, "organization_name");
  const date = formatDetailDate(field(enc, "start_datetime"));

  return (
    <div className="flex items-start justify-between gap-3 px-4 py-3">
      <div className="min-w-0">
        <p className="truncate text-[13px] font-semibold text-ink">{capitalise(type)}</p>
        {practitioner && (
          <p className="mt-0.5 text-[12px] text-ink-faint">
            {dm.share.doctorPrefix} {practitioner}
          </p>
        )}
        {org && <p className="mt-0.5 text-[12px] text-ink-faint">{org}</p>}
      </div>
      <p className="shrink-0 text-[12px] text-ink-muted">{date}</p>
    </div>
  );
}
