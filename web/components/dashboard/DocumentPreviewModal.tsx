"use client";

import { useEffect, useState } from "react";
import {
  ArrowsClockwise,
  DownloadSimple,
  MagnifyingGlassMinus,
  MagnifyingGlassPlus,
  WarningCircle,
  X,
} from "@phosphor-icons/react/dist/ssr";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

const MIME_EXTENSIONS: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/gif": "gif",
  "image/webp": "webp",
  "image/heic": "heic",
  "application/pdf": "pdf",
};

const MIN_ZOOM = 0.5;
const MAX_ZOOM = 3;
const ZOOM_STEP = 0.25;

async function downloadFile(url: string, filename: string) {
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error("Download failed");
    const blob = await response.blob();
    const blobUrl = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = blobUrl;
    link.download = filename;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(blobUrl);
  } catch {
    // Cross-origin fetch was blocked or failed - fall back to a same-tab navigation.
    // The pre-signed URL carries a Content-Disposition: attachment header, so this
    // still downloads the file instead of opening/rendering it in a new tab.
    window.location.assign(url);
  }
}

export function DocumentPreviewModal({
  open,
  onClose,
  title,
  url,
  mimeType,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  url: string;
  mimeType: string;
}) {
  const dm = useDashboardMessages();
  const [failed, setFailed] = useState(false);
  const [zoom, setZoom] = useState(1);

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

  const isImage = mimeType.startsWith("image/");
  const isPdf = mimeType === "application/pdf";
  const canPreview = isImage || isPdf;
  const filename = `${title}${MIME_EXTENSIONS[mimeType] ? `.${MIME_EXTENSIONS[mimeType]}` : ""}`;

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
        aria-labelledby="document-preview-title"
        className="flex h-[85vh] w-full max-w-3xl flex-col overflow-hidden rounded-2xl border border-border bg-card shadow-lg"
      >
        <div className="flex items-center justify-between gap-4 border-b border-border px-6 py-4">
          <h2 id="document-preview-title" className="truncate text-base font-semibold text-ink">
            {title}
          </h2>
          <div className="flex shrink-0 items-center gap-2">
            <button
              type="button"
              onClick={() => downloadFile(url, filename)}
              className="flex h-8 w-8 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-primary max-lg:h-11 max-lg:w-11"
              aria-label={dm.common.download}
              title={dm.common.download}
            >
              <DownloadSimple size={16} />
            </button>
            <button
              type="button"
              onClick={onClose}
              aria-label={dm.common.close}
              className="flex h-8 w-8 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-ink max-lg:h-11 max-lg:w-11"
            >
              <X size={16} />
            </button>
          </div>
        </div>

        {isImage && !failed && (
          <div className="flex items-center justify-end gap-1 border-b border-border bg-card px-4 py-2">
            <button
              type="button"
              onClick={() => setZoom((z) => Math.max(MIN_ZOOM, +(z - ZOOM_STEP).toFixed(2)))}
              disabled={zoom <= MIN_ZOOM}
              className="flex h-7 w-7 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-primary disabled:opacity-40 max-lg:h-9 max-lg:w-9"
              aria-label={dm.document.zoomOut}
              title={dm.document.zoomOut}
            >
              <MagnifyingGlassMinus size={15} />
            </button>
            <span className="w-12 text-center text-xs font-medium text-ink-muted">{Math.round(zoom * 100)}%</span>
            <button
              type="button"
              onClick={() => setZoom((z) => Math.min(MAX_ZOOM, +(z + ZOOM_STEP).toFixed(2)))}
              disabled={zoom >= MAX_ZOOM}
              className="flex h-7 w-7 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-primary disabled:opacity-40 max-lg:h-9 max-lg:w-9"
              aria-label={dm.document.zoomIn}
              title={dm.document.zoomIn}
            >
              <MagnifyingGlassPlus size={15} />
            </button>
            <button
              type="button"
              onClick={() => setZoom(1)}
              disabled={zoom === 1}
              className="ms-1 flex h-7 w-7 items-center justify-center rounded-full text-ink-faint hover:bg-surface hover:text-primary disabled:opacity-40 max-lg:h-9 max-lg:w-9"
              aria-label={dm.document.resetZoom}
              title={dm.document.resetZoom}
            >
              <ArrowsClockwise size={15} />
            </button>
          </div>
        )}

        <div className="flex flex-1 items-center justify-center overflow-auto bg-surface p-4">
          {!canPreview || failed ? (
            <div className="flex flex-col items-center gap-3 text-center">
              <WarningCircle size={32} className="text-ink-faint" />
              <p className="max-w-xs text-sm text-ink-muted">{dm.document.previewUnavailable}</p>
              <div className="mt-1 flex items-center gap-3">
                <button
                  type="button"
                  onClick={() => downloadFile(url, filename)}
                  className="rounded-full bg-primary px-5 py-2 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
                >
                  {dm.common.download}
                </button>
              </div>
            </div>
          ) : isImage ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={url}
              alt={title}
              style={{ width: `${zoom * 100}%`, maxWidth: zoom <= 1 ? "100%" : "none" }}
              className="mx-auto h-auto rounded-lg object-contain"
              onError={() => setFailed(true)}
            />
          ) : (
            <iframe src={url} title={title} className="h-full w-full rounded-lg border border-border bg-white" />
          )}
        </div>
      </div>
    </div>
  );
}
