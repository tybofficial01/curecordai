"use client";

import { useCallback, useEffect, useState } from "react";
import Cropper, { type Area } from "react-easy-crop";
import { getCroppedImageBlob } from "@/lib/utils/cropImage";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

type AvatarCropModalProps = {
  imageSrc: string;
  onCancel: () => void;
  onSave: (blob: Blob) => void;
};

export function AvatarCropModal({ imageSrc, onCancel, onSave }: AvatarCropModalProps) {
  const dm = useDashboardMessages();
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState<Area | null>(null);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === "Escape") onCancel();
    }
    document.addEventListener("keydown", handleKeyDown);
    const { overflow } = document.body.style;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", handleKeyDown);
      document.body.style.overflow = overflow;
    };
  }, [onCancel]);

  const handleCropComplete = useCallback((_area: Area, areaPixels: Area) => {
    setCroppedAreaPixels(areaPixels);
  }, []);

  async function handleSave() {
    if (!croppedAreaPixels) return;
    setSaving(true);
    setError("");
    try {
      const blob = await getCroppedImageBlob(imageSrc, croppedAreaPixels);
      onSave(blob);
    } catch {
      setError(dm.profile.cropError);
      setSaving(false);
    }
  }

  return (
    <div
      className="fixed inset-0 z-[100] flex items-center justify-center bg-black/50 p-4 backdrop-blur-sm"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) onCancel();
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="avatar-crop-title"
        className="max-h-[90vh] w-full max-w-sm overflow-y-auto rounded-2xl border border-border bg-card p-6 shadow-lg"
      >
        <h2 id="avatar-crop-title" className="text-base font-semibold text-ink">
          {dm.profile.cropPhotoTitle}
        </h2>

        <div className="relative mt-4 h-72 w-full overflow-hidden rounded-xl bg-surface">
          <Cropper
            image={imageSrc}
            crop={crop}
            zoom={zoom}
            aspect={1}
            cropShape="round"
            showGrid={false}
            onCropChange={setCrop}
            onZoomChange={setZoom}
            onCropComplete={handleCropComplete}
          />
        </div>

        <div className="mt-4 flex items-center gap-3">
          <span className="text-xs font-medium text-ink-muted">{dm.profile.zoom}</span>
          <input
            type="range"
            min={1}
            max={3}
            step={0.05}
            value={zoom}
            onChange={(e) => setZoom(Number(e.target.value))}
            className="w-full accent-primary"
            aria-label={dm.profile.zoom}
          />
        </div>

        {error && <p className="mt-3 text-sm font-medium text-error">{error}</p>}

        <div className="mt-6 flex justify-end gap-3">
          <button
            type="button"
            onClick={onCancel}
            disabled={saving}
            className="rounded-full border border-border px-5 py-2.5 text-sm font-semibold text-ink hover:bg-surface disabled:opacity-50"
          >
            {dm.common.cancel}
          </button>
          <button
            type="button"
            onClick={handleSave}
            disabled={saving || !croppedAreaPixels}
            className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-50"
          >
            {saving ? dm.common.saving : dm.common.save}
          </button>
        </div>
      </div>
    </div>
  );
}
