"use client";

import { useEffect, useState } from "react";
import { useAuth } from "@/lib/auth/AuthContext";
import { createFolder } from "@/lib/api/records";
import { ApiError } from "@/lib/api/client";
import { FOLDER_ICON_OPTIONS } from "@/lib/folderIcons";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";
import type { RecordFolder } from "@/lib/api/types";

const DEFAULT_ICON_KEY = "heart";

export function CreateFolderModal({
  open,
  onClose,
  onCreated,
}: {
  open: boolean;
  onClose: () => void;
  onCreated: (folder: RecordFolder) => void;
}) {
  const { getAccessToken } = useAuth();
  const dm = useDashboardMessages();
  const [name, setName] = useState("");
  const [iconKey, setIconKey] = useState(DEFAULT_ICON_KEY);
  const [error, setError] = useState("");
  const [isCreating, setIsCreating] = useState(false);

  // Resets the form when the modal is dismissed (rather than when it opens) so the reset
  // is a direct consequence of a user action, not a setState-in-effect side effect.
  function resetAndClose() {
    setName("");
    setIconKey(DEFAULT_ICON_KEY);
    setError("");
    onClose();
  }

  useEffect(() => {
    if (!open) return;
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") resetAndClose();
    }
    document.addEventListener("keydown", handleKeyDown);
    const { overflow } = document.body.style;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = overflow;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  async function handleCreate() {
    const trimmed = name.trim();
    if (!trimmed) {
      setError(dm.upload.folder.nameRequired);
      return;
    }
    setError("");
    setIsCreating(true);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      const folder = await createFolder(token, { name: trimmed, icon: iconKey });
      onCreated(folder);
      resetAndClose();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.upload.folder.createError);
    } finally {
      setIsCreating(false);
    }
  }

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) resetAndClose();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="create-folder-title"
        className="max-h-[90vh] w-full max-w-sm overflow-y-auto rounded-2xl border border-border bg-card p-6 shadow-lg"
      >
        <h2 id="create-folder-title" className="text-base font-semibold text-ink">
          {dm.upload.folder.title}
        </h2>
        <p className="mt-1 text-sm text-ink-muted">{dm.upload.folder.description}</p>

        <label htmlFor="folder-name" className="mt-5 block text-sm font-medium text-ink">
          {dm.upload.folder.nameLabel}
        </label>
        <input
          id="folder-name"
          type="text"
          autoFocus
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder={dm.upload.folder.namePlaceholder}
          maxLength={100}
          className="mt-1.5 w-full rounded-xl border border-border bg-background px-4 py-3 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
        />

        <p className="mt-5 text-sm font-medium text-ink">{dm.upload.folder.selectIcon}</p>
        <div className="mt-2 flex flex-wrap gap-3">
          {FOLDER_ICON_OPTIONS.map(({ key, icon: OptionIcon, label }) => {
            const selected = key === iconKey;
            return (
              <button
                key={key}
                type="button"
                onClick={() => setIconKey(key)}
                aria-label={label}
                aria-pressed={selected}
                className={`flex h-[52px] w-[52px] shrink-0 items-center justify-center rounded-full border transition-colors ${
                  selected
                    ? "border-primary bg-primary text-primary-foreground"
                    : "border-border bg-background text-ink-muted hover:border-primary hover:text-primary"
                }`}
              >
                <OptionIcon size={22} />
              </button>
            );
          })}
        </div>

        {error && <p className="mt-4 text-sm text-error">{error}</p>}

        <button
          type="button"
          onClick={handleCreate}
          disabled={isCreating}
          className="mt-6 w-full rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-70"
        >
          {isCreating ? dm.upload.folder.creating : dm.upload.folder.create}
        </button>
        <button
          type="button"
          onClick={resetAndClose}
          className="mt-2 w-full rounded-full px-6 py-2.5 text-sm font-semibold text-ink-muted hover:text-ink"
        >
          {dm.common.cancel}
        </button>
      </div>
    </div>
  );
}
