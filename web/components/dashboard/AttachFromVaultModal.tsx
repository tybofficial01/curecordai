"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import {
  ArrowsLeftRight,
  Check,
  FileText,
  Flask,
  FolderSimple,
  MagnifyingGlass,
  Pill,
  Scan,
  ShieldCheck,
  Syringe,
} from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { listRecords } from "@/lib/api/records";
import { EmptyState } from "@/components/dashboard/EmptyState";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";
import type { MedicalRecord, RecordType } from "@/lib/api/types";

const recordTypeIcons: Record<RecordType, Icon> = {
  lab_report: Flask,
  prescription: Pill,
  radiology: Scan,
  discharge_summary: FileText,
  vaccination: Syringe,
  insurance: ShieldCheck,
  referral: ArrowsLeftRight,
  other: FolderSimple,
};

async function loadVaultRecords(token: string, familyMemberId?: string) {
  const records = await listRecords(token, { family_member_id: familyMemberId });
  return records.sort((a, b) => new Date(b.uploaded_at).getTime() - new Date(a.uploaded_at).getTime());
}

export function AttachFromVaultModal({
  open,
  onClose,
  onAttach,
  scopeId,
}: {
  open: boolean;
  onClose: () => void;
  onAttach: (records: { id: string; title: string }[]) => void;
  scopeId?: string;
}) {
  const dm = useDashboardMessages();
  const { data: records, isLoading } = useCachedResource(
    open ? `vault-records-${scopeId ?? "self"}` : null,
    (token) => loadVaultRecords(token, scopeId)
  );
  const [query, setQuery] = useState("");
  const [selectedIds, setSelectedIds] = useState<string[]>([]);

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

  const filtered = useMemo(() => {
    if (!records) return [];
    const q = query.trim().toLowerCase();
    if (!q) return records;
    return records.filter((record) => record.title.toLowerCase().includes(q));
  }, [records, query]);

  function toggleSelected(record: MedicalRecord) {
    setSelectedIds((prev) =>
      prev.includes(record.id) ? prev.filter((id) => id !== record.id) : [...prev, record.id]
    );
  }

  function handleAttach() {
    if (!records) return;
    const selected = records
      .filter((r) => selectedIds.includes(r.id))
      .map((r) => ({ id: r.id, title: r.title }));
    onAttach(selected);
    onClose();
  }

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
        aria-labelledby="attach-vault-title"
        className="flex max-h-[80vh] w-full max-w-lg flex-col rounded-2xl border border-border bg-card shadow-lg"
      >
        <div className="border-b border-border p-6 pb-4">
          <h2 id="attach-vault-title" className="text-base font-semibold text-ink">
            {dm.assistant.attach.title}
          </h2>
          <p className="mt-1 text-sm text-ink-muted">{dm.assistant.attach.description}</p>

          <div className="relative mt-4">
            <MagnifyingGlass
              size={16}
              className="pointer-events-none absolute start-4 top-1/2 -translate-y-1/2 text-ink-faint"
            />
            <input
              type="search"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              placeholder={dm.assistant.attach.searchPlaceholder}
              className="w-full rounded-full border border-border bg-surface py-2.5 ps-11 pe-4 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
          </div>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto p-3">
          {isLoading && (
            <div className="flex flex-col gap-2 p-3">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-14" />
              ))}
            </div>
          )}

          {!isLoading && records && records.length === 0 && (
            <EmptyState
              icon={FolderSimple}
              title={dm.assistant.attach.emptyTitle}
              description={dm.assistant.attach.emptyDescription}
              action={
                <Link
                  href="/dashboard/upload"
                  className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
                >
                  {dm.vault.uploadDocument}
                </Link>
              }
            />
          )}

          {!isLoading && records && records.length > 0 && filtered.length === 0 && (
            <p className="px-3 py-8 text-center text-sm text-ink-muted">{dm.assistant.attach.noMatches}</p>
          )}

          {!isLoading &&
            filtered.map((record) => {
              const RecordIcon = recordTypeIcons[record.record_type];
              const isSelected = selectedIds.includes(record.id);
              return (
                <button
                  key={record.id}
                  type="button"
                  onClick={() => toggleSelected(record)}
                  aria-pressed={isSelected}
                  className={`flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-start transition-colors ${
                    isSelected ? "bg-primary-tint" : "hover:bg-surface"
                  }`}
                >
                  <span
                    className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${
                      isSelected ? "bg-primary text-primary-foreground" : "bg-primary-tint text-primary"
                    }`}
                  >
                    <RecordIcon size={18} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold text-ink">{record.title}</span>
                    <span className="block truncate text-xs text-ink-muted">
                      {dm.recordTypes[record.record_type]} &middot; {dm.documentStatus[record.processing_status]}
                    </span>
                  </span>
                  <span
                    className={`flex h-5 w-5 shrink-0 items-center justify-center rounded-md border ${
                      isSelected ? "border-primary bg-primary text-primary-foreground" : "border-border"
                    }`}
                  >
                    {isSelected && <Check size={12} weight="bold" />}
                  </span>
                </button>
              );
            })}
        </div>

        <div className="flex justify-end gap-3 border-t border-border p-4">
          <button
            type="button"
            onClick={onClose}
            className="rounded-full border border-border px-5 py-2.5 text-sm font-semibold text-ink hover:bg-surface"
          >
            {dm.common.cancel}
          </button>
          <button
            type="button"
            onClick={handleAttach}
            disabled={selectedIds.length === 0}
            className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
          >
            {dm.assistant.attach.attachButton}{selectedIds.length > 0 ? ` (${selectedIds.length})` : ""}
          </button>
        </div>
      </div>
    </div>
  );
}
