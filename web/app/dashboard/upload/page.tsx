"use client";

import { useRef, useState, type ChangeEvent, type DragEvent } from "react";
import { useRouter } from "next/navigation";
import { CloudArrowUp, FileText, CheckCircle, Plus, WarningCircle } from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import {
  computeSha256Hex,
  confirmUpload,
  deleteRecord,
  getRecord,
  initUpload,
  listFolders,
  postFileToS3,
} from "@/lib/api/records";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { ApiError } from "@/lib/api/client";
import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { CreateFolderModal } from "@/components/dashboard/CreateFolderModal";
import type { RecordFolder } from "@/lib/api/types";

const MAX_FILE_SIZE_BYTES = 50 * 1024 * 1024;
const ALLOWED_MIME_TYPES = ["application/pdf", "image/jpeg", "image/png", "image/webp", "application/dicom"];

// How long we're willing to hold the upload button in "Checking document..." while the backend's
// AI pipeline extracts and verifies the document (that it's a genuine medical record and that the
// patient name matches the profile) before we'll declare the upload successful.
const DOCUMENT_CHECK_POLL_INTERVAL_MS = 1500;
const DOCUMENT_CHECK_MAX_ATTEMPTS = 30;

/** Browsers report an empty `file.type` for extensions they don't recognize, e.g. `.dcm` - fall
 *  back to the extension so the file isn't misdeclared as `application/octet-stream` and rejected
 *  by the backend's mime allowlist despite the upload picker advertising DICOM support. */
function resolveMimeType(file: File): string {
  if (file.type) return file.type;
  if (file.name.toLowerCase().endsWith(".dcm")) return "application/dicom";
  return "application/octet-stream";
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export default function UploadPage() {
  const { getAccessToken } = useAuth();
  const router = useRouter();
  const dm = useDashboardMessages();
  const { profile: activeProfile } = useActiveProfile();
  const scopeId = activeProfile.isOwnerMode ? null : activeProfile.memberId;

  const [file, setFile] = useState<File | null>(null);
  const [dragActive, setDragActive] = useState(false);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  // Holds a message key rather than a rendered string so a mid-upload language
  // switch re-renders the button in the new language instead of freezing the
  // label captured when the upload started.
  const [submitStage, setSubmitStage] = useState<"uploading" | "checking">("uploading");
  const [uploadedRecordId, setUploadedRecordId] = useState<string | null>(null);
  const [folderId, setFolderId] = useState<string | null>(null);
  const [isCreateFolderOpen, setIsCreateFolderOpen] = useState(false);
  const abortControllerRef = useRef<AbortController | null>(null);
  const [uploadRejectedMessage, setUploadRejectedMessage] = useState<string | null>(null);

  const { data: folders, setData: setFolders } = useCachedResource<RecordFolder[]>("record-folders", (token) =>
    listFolders(token)
  );

  function handleFolderCreated(folder: RecordFolder) {
    setFolders((prev) => [...(prev ?? []), folder]);
    setFolderId(folder.id);
  }

  function pickFile(picked: File) {
    if (submitting) return;
    if (picked.size > MAX_FILE_SIZE_BYTES) {
      setError(dm.upload.tooLarge);
      return;
    }
    if (!ALLOWED_MIME_TYPES.includes(resolveMimeType(picked))) {
      setError(dm.upload.unsupportedType);
      return;
    }
    setError("");
    setFile(picked);
  }

  function handleFileInput(event: ChangeEvent<HTMLInputElement>) {
    const picked = event.target.files?.[0];
    if (picked) pickFile(picked);
  }

  function handleDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault();
    setDragActive(false);
    const picked = event.dataTransfer.files?.[0];
    if (picked) pickFile(picked);
  }

  async function handleUpload() {
    if (!file) {
      setError(dm.upload.chooseFile);
      return;
    }
    setError("");
    setSubmitting(true);
    const controller = new AbortController();
    abortControllerRef.current = controller;
    let createdRecordId: string | null = null;
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);

      const mimeType = resolveMimeType(file);
      // No title or document type to collect here - the backend defaults them (title "Untitled",
      // type "other") and the AI pipeline overwrites both with the real title/category once it
      // finishes analyzing the document. family_member_id is threaded through so the upload
      // attaches to whichever profile is active in the top switcher, not always the owner.
      const init = await initUpload(
        token,
        {
          file_name: file.name,
          file_mime_type: mimeType,
          file_size_bytes: file.size,
          family_member_id: scopeId,
          folder_id: folderId,
        },
        controller.signal
      );
      createdRecordId = init.record_id;

      await postFileToS3(init.upload_url, init.upload_fields, file, controller.signal);
      const fileHash = await computeSha256Hex(file);
      await confirmUpload(token, init.record_id, fileHash, controller.signal);

      // The document is only actually verified (whether it's even a medical record, and whether
      // the patient name matches the profile) once the AI pipeline finishes analyzing it - hold
      // the button in a "checking" state and wait for a terminal status rather than declaring
      // success prematurely.
      setSubmitStage("checking");
      let finalStatus: "pending" | "processing" | "completed" | "failed" = "pending";
      let finalError: string | null = null;
      for (let attempt = 0; attempt < DOCUMENT_CHECK_MAX_ATTEMPTS; attempt++) {
        const current = await getRecord(token, init.record_id);
        finalStatus = current.processing_status;
        finalError = current.processing_error;
        if (finalStatus === "completed" || finalStatus === "failed") break;
        await sleep(DOCUMENT_CHECK_POLL_INTERVAL_MS);
      }

      if (finalStatus === "failed") {
        await deleteRecord(token, init.record_id);
        createdRecordId = null;
        setUploadRejectedMessage(finalError ?? dm.upload.couldNotVerify);
        setFile(null);
        return;
      }

      // Still pending/processing after the poll window (unusually slow AI pipeline) - the record
      // is real and will finish in the background, so let the user through to the vault rather
      // than blocking indefinitely; any issue found later still surfaces on the document page.
      setUploadedRecordId(init.record_id);
    } catch (err) {
      // The backend already created a "pending" record row during init - if the S3 upload or
      // confirm step fails after that (including a user-initiated cancel), clean it up so it
      // doesn't sit forever as a ghost entry stuck on "Uploading" in the vault.
      if (createdRecordId) {
        try {
          const token = await getAccessToken();
          if (token) await deleteRecord(token, createdRecordId);
        } catch {
          // best-effort cleanup; the error below still surfaces to the user either way
        }
      }
      if (!(err instanceof DOMException && err.name === "AbortError")) {
        if (err instanceof ApiError && err.status === 409) {
          setError(dm.upload.duplicateRecord);
        } else {
          setError(err instanceof ApiError ? err.message : err instanceof Error ? err.message : dm.upload.uploadFailed);
        }
      }
    } finally {
      setSubmitting(false);
      abortControllerRef.current = null;
      setSubmitStage("uploading");
    }
  }

  function handleCancelUpload() {
    abortControllerRef.current?.abort();
  }

  if (uploadedRecordId) {
    return (
      <div className="mx-auto max-w-lg text-center">
        <span className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-primary-tint text-primary">
          <CheckCircle size={32} weight="fill" />
        </span>
        <h1 className="mt-4 text-2xl font-bold text-ink">{dm.upload.successTitle}</h1>
        <p className="mt-2 text-sm text-ink-muted">
          {formatMessage(dm.upload.successDescription, { name: file?.name ?? "" })}
        </p>
        <div className="mt-6 flex justify-center gap-3">
          <button
            type="button"
            onClick={() => router.push(`/dashboard/vault/${uploadedRecordId}`)}
            className="rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
          >
            {dm.upload.viewDocument}
          </button>
          <button
            type="button"
            onClick={() => {
              setUploadedRecordId(null);
              setFile(null);
              setFolderId(null);
            }}
            className="rounded-full border border-border px-6 py-3 text-sm font-semibold text-ink hover:bg-surface"
          >
            {dm.upload.uploadAnother}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-2xl">
      <PageHeading
        title={dm.upload.title}
        description={dm.upload.description}
      />

      <div className="flex flex-col gap-6">
        <div
          onDragOver={(e) => {
            e.preventDefault();
            if (!submitting) setDragActive(true);
          }}
          onDragLeave={() => setDragActive(false)}
          onDrop={handleDrop}
          className={`flex flex-col items-center gap-3 rounded-2xl border-2 border-dashed px-6 py-12 text-center transition-colors ${
            submitting ? "pointer-events-none opacity-60" : ""
          } ${dragActive ? "border-primary bg-primary-tint/40" : "border-border bg-card"}`}
        >
          {file ? (
            <>
              <FileText size={36} className="text-primary" weight="duotone" />
              <p className="text-sm font-semibold text-ink">{file.name}</p>
            </>
          ) : (
            <>
              <CloudArrowUp size={36} className="text-primary" weight="duotone" />
              <p className="text-sm font-semibold text-ink">{dm.upload.dropHere}</p>
            </>
          )}
          <p className="text-xs text-ink-muted">{dm.upload.fileHint}</p>
          <label className="mt-2 cursor-pointer rounded-full border border-border px-5 py-2.5 text-sm font-medium text-ink hover:bg-surface">
            {dm.upload.browseFiles}
            <input
              type="file"
              className="hidden"
              accept=".pdf,.jpg,.jpeg,.png,.webp,.dcm"
              onChange={handleFileInput}
              disabled={submitting}
            />
          </label>
        </div>

        <div>
          <label htmlFor="folder" className="block text-sm font-medium text-ink">
            {dm.upload.selectFolder}
          </label>
          <div className="mt-1.5 flex gap-2">
            <select
              id="folder"
              value={folderId ?? ""}
              onChange={(e) => setFolderId(e.target.value || null)}
              className="w-full min-w-0 flex-1 rounded-xl border border-border bg-card px-4 py-3 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            >
              <option value="">{dm.upload.generalRecords}</option>
              {(folders ?? []).map((folder) => (
                <option key={folder.id} value={folder.id}>
                  {folder.name}
                </option>
              ))}
            </select>
            <button
              type="button"
              onClick={() => setIsCreateFolderOpen(true)}
              className="flex shrink-0 items-center gap-1.5 rounded-xl border border-border px-4 py-3 text-sm font-medium text-ink hover:bg-surface"
            >
              <Plus size={16} /> {dm.upload.newFolder}
            </button>
          </div>
        </div>

        {error && <p className="text-sm font-medium text-error">{error}</p>}

        <button
          type="button"
          onClick={handleUpload}
          disabled={submitting || !file}
          className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
        >
          {submitting
            ? submitStage === "checking"
              ? dm.upload.checkingDocument
              : dm.upload.uploading
            : dm.upload.uploadButton}
        </button>

        {submitting && (
          <button
            type="button"
            onClick={handleCancelUpload}
            className="rounded-full border border-border px-6 py-3 text-base font-semibold text-ink transition-colors hover:bg-surface"
          >
            {dm.common.cancel}
          </button>
        )}
      </div>

      <CreateFolderModal
        open={isCreateFolderOpen}
        onClose={() => setIsCreateFolderOpen(false)}
        onCreated={handleFolderCreated}
      />

      {uploadRejectedMessage && (
        <div
          className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
          onMouseDown={(event) => {
            if (event.target === event.currentTarget) setUploadRejectedMessage(null);
          }}
        >
          <div
            role="alertdialog"
            aria-modal="true"
            aria-labelledby="upload-rejected-title"
            className="max-h-[90vh] w-full max-w-sm overflow-y-auto rounded-2xl border border-border bg-card p-6 text-center shadow-lg"
          >
            <span className="mx-auto flex h-14 w-14 items-center justify-center rounded-full bg-error/10 text-error">
              <WarningCircle size={28} weight="fill" />
            </span>
            <h2 id="upload-rejected-title" className="mt-4 text-base font-semibold text-ink">
              {dm.upload.rejectedTitle}
            </h2>
            <p className="mt-2 text-sm text-ink-muted">{dm.upload.rejectedDescription}</p>
            <p className="mt-3 rounded-xl bg-surface px-3.5 py-2.5 text-xs text-ink-muted">{uploadRejectedMessage}</p>
            <button
              type="button"
              onClick={() => setUploadRejectedMessage(null)}
              className="mt-6 w-full rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
            >
              {dm.common.tryAgain}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
