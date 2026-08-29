"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { FolderSimple, MagnifyingGlass } from "@phosphor-icons/react/dist/ssr";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { listRecords, listFolders } from "@/lib/api/records";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { EmptyState } from "@/components/dashboard/EmptyState";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { RECORD_TYPES, type RecordType } from "@/lib/api/types";
import { folderIconFor } from "@/lib/folderIcons";

async function loadVaultRecords(token: string, familyMemberId?: string | null) {
  const records = await listRecords(token, { family_member_id: familyMemberId ?? undefined });
  return records.sort((a, b) => new Date(b.uploaded_at).getTime() - new Date(a.uploaded_at).getTime());
}

export default function VaultPage() {
  const { profile: activeProfile } = useActiveProfile();
  const dm = useDashboardMessages();
  const scopeId = activeProfile.isOwnerMode ? null : activeProfile.memberId;
  const { data: records, isLoading, error } = useCachedResource(`vault-records-${scopeId ?? "self"}`, (token) =>
    loadVaultRecords(token, scopeId)
  );
  const { data: folders } = useCachedResource("record-folders", (token) => listFolders(token));
  const [activeType, setActiveType] = useState<RecordType | "all">("all");
  const [activeFolderId, setActiveFolderId] = useState<string | null>(null);
  const [query, setQuery] = useState("");

  // Only surface category chips that at least one uploaded document actually uses, so a family
  // that has never uploaded e.g. a Referral doesn't see a permanently-empty "Referral" filter.
  const availableTypes = useMemo(() => {
    if (!records) return [];
    const present = new Set(records.map((record) => record.record_type));
    return RECORD_TYPES.filter((type) => present.has(type));
  }, [records]);

  const filtered = useMemo(() => {
    if (!records) return [];
    return records.filter((record) => {
      const matchesType = activeType === "all" || record.record_type === activeType;
      const matchesFolder = !activeFolderId || record.folder_id === activeFolderId;
      const matchesQuery =
        query.trim().length === 0 || record.title.toLowerCase().includes(query.toLowerCase());
      return matchesType && matchesFolder && matchesQuery;
    });
  }, [records, activeType, activeFolderId, query]);

  return (
    <div>
      {/* Inlined rather than using the shared PageHeading component so the button can be left
          aligned under the description on mobile instead of floating centered, without
          changing PageHeading's centered-action layout used by every other page. Desktop
          keeps the exact same row layout and spacing as PageHeading produces. */}
      <div className="mb-4 flex flex-col gap-4 sm:mb-8 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <h1 className="text-2xl font-bold text-ink sm:text-3xl">{dm.vault.title}</h1>
          <p className="mt-1 text-sm text-ink-muted">{dm.vault.description}</p>
        </div>
        <Link
          href="/dashboard/upload"
          className="self-start rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90 sm:self-center"
        >
          {dm.vault.uploadDocument}
        </Link>
      </div>

      {isLoading && (
        <div className="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-28" />
          ))}
        </div>
      )}
      {error && <p className="text-sm text-error">{error}</p>}

      {records && (
        <>
          <div className="flex flex-col gap-4">
            <div className="relative">
              <MagnifyingGlass
                size={18}
                className="pointer-events-none absolute start-4 top-1/2 -translate-y-1/2 text-ink-faint"
              />
              <input
                type="search"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder={dm.vault.searchPlaceholder}
                className="w-full rounded-full border border-border bg-card py-3 ps-11 pe-4 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />
            </div>

            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => {
                  setActiveType("all");
                  setActiveFolderId(null);
                }}
                className={`rounded-full border px-4 py-2 text-sm font-medium transition-colors ${
                  activeType === "all" && !activeFolderId
                    ? "border-primary bg-primary text-primary-foreground"
                    : "border-border bg-card text-ink-muted hover:border-primary hover:text-primary"
                }`}
              >
                {dm.common.all}
              </button>
              {availableTypes.map((type) => (
                <button
                  key={type}
                  type="button"
                  onClick={() => {
                    setActiveType(type);
                    setActiveFolderId(null);
                  }}
                  className={`rounded-full border px-4 py-2 text-sm font-medium transition-colors ${
                    activeType === type && !activeFolderId
                      ? "border-primary bg-primary text-primary-foreground"
                      : "border-border bg-card text-ink-muted hover:border-primary hover:text-primary"
                  }`}
                >
                  {dm.recordTypes[type]}
                </button>
              ))}
              {(folders ?? []).map((folder) => {
                const FolderIcon = folderIconFor(folder.icon);
                const isActive = activeFolderId === folder.id;
                return (
                  <button
                    key={folder.id}
                    type="button"
                    onClick={() => {
                      setActiveFolderId(isActive ? null : folder.id);
                      setActiveType("all");
                    }}
                    className={`flex items-center gap-1.5 rounded-full border px-4 py-2 text-sm font-medium transition-colors ${
                      isActive
                        ? "border-primary bg-primary text-primary-foreground"
                        : "border-border bg-card text-ink-muted hover:border-primary hover:text-primary"
                    }`}
                  >
                    <FolderIcon size={15} />
                    {folder.name}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="mt-6">
            {filtered.length === 0 ? (
              <EmptyState
                icon={FolderSimple}
                title={dm.vault.emptyTitle}
                description={dm.vault.emptyDescription}
              />
            ) : (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {filtered.map((record) => (
                  <Link
                    key={record.id}
                    href={`/dashboard/vault/${record.id}`}
                    className="flex flex-col gap-3 rounded-2xl border border-border bg-card p-5 hover:border-primary"
                  >
                    <span className="flex h-11 w-11 items-center justify-center rounded-full bg-primary-tint text-primary">
                      <FolderSimple size={20} />
                    </span>
                    <div>
                      <p className="text-sm font-semibold text-ink">{record.title}</p>
                      <p className="mt-1 text-xs text-ink-muted">
                        {dm.recordTypes[record.record_type]} &middot;{" "}
                        {dm.recordStatus[record.processing_status]}
                      </p>
                    </div>
                    <p className="text-xs text-ink-faint">
                      {new Date(record.uploaded_at).toLocaleDateString()}
                    </p>
                  </Link>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
}
