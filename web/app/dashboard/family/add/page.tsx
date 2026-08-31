"use client";

import { Suspense, useEffect, useState, type FormEvent } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";
import { mutate } from "swr";
import { ArrowLeft, Info, Plus, WarningCircle, X } from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { createFamilyMember, listFamilyMembers, updateFamilyMember } from "@/lib/api/family";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { ApiError } from "@/lib/api/client";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";
import { useToast } from "@/lib/toast/ToastProvider";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { Select } from "@/components/ui/Select";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { BLOOD_GROUPS } from "@/lib/api/types";

// Values go to the backend verbatim, so the English keys stay canonical - only the
// label the user reads is translated (dm.family.add.relations).
const relations = ["Spouse", "Parent", "Father", "Mother", "Child", "Son", "Daughter", "Sibling", "Other"] as const;
type Relation = (typeof relations)[number];

function relationLabel(dm: DashboardMessages, relation: Relation): string {
  return dm.family.add.relations[relation];
}

function getInitials(fullName: string): string {
  const parts = fullName.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "";
  const first = parts[0].charAt(0);
  const last = parts.length > 1 ? parts[parts.length - 1].charAt(0) : "";
  return (first + last).toUpperCase();
}

function RelationRoleInfoModal({ open, onClose, dm }: { open: boolean; onClose: () => void; dm: DashboardMessages }) {
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
        aria-labelledby="relation-role-info-title"
        className="max-h-[90vh] w-full max-w-sm overflow-y-auto rounded-2xl border border-border bg-card p-6 shadow-lg"
      >
        <div className="flex items-start justify-between gap-4">
          <h2 id="relation-role-info-title" className="text-base font-semibold text-ink">
            {dm.family.add.infoTitle}
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

        <p className="mt-3 text-sm leading-relaxed text-ink-muted">{dm.family.add.infoBody}</p>

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

export default function AddFamilyMemberPage() {
  return (
    <Suspense fallback={null}>
      <AddFamilyMemberForm />
    </Suspense>
  );
}

function AddFamilyMemberForm() {
  const { getAccessToken } = useAuth();
  const router = useRouter();
  const searchParams = useSearchParams();
  const dm = useDashboardMessages();
  const showToast = useToast();
  const editId = searchParams.get("edit");
  const isEditing = Boolean(editId);

  // Same SWR key the Family Management page uses, so this reuses its cache instead of firing a
  // second request when the list is already warm, and only fetches at all when actually editing.
  const { data: members } = useCachedResource(isEditing ? "family-members" : null, listFamilyMembers);
  const editingMember = editId ? (members?.find((m) => m.id === editId) ?? null) : null;
  const stillLoadingEditTarget = isEditing && !editingMember;

  const requestedRelation = searchParams.get("relation");
  const initialRelation = relations.includes(requestedRelation as Relation)
    ? (requestedRelation as Relation)
    : relations[0];
  const [fullName, setFullName] = useState("");
  const [relationship, setRelationship] = useState<Relation>(initialRelation);
  const [role, setRole] = useState<"dependent" | "caregiver">("dependent");
  const [gender, setGender] = useState("male");
  const [bloodGroup, setBloodGroup] = useState("");
  const [dateOfBirth, setDateOfBirth] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [infoOpen, setInfoOpen] = useState(false);

  useEffect(() => {
    if (!editingMember) return;
    setFullName(editingMember.full_name);
    setRelationship(
      relations.includes(editingMember.relationship as Relation)
        ? (editingMember.relationship as Relation)
        : "Other"
    );
    setRole(editingMember.role);
    setGender(editingMember.gender ?? "male");
    setBloodGroup(editingMember.blood_group ?? "");
    setDateOfBirth(editingMember.date_of_birth ?? "");
  }, [editingMember]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (fullName.trim().length < 2) {
      setError(dm.family.add.nameTooShort);
      return;
    }
    setError("");
    setSubmitting(true);
    const trimmedName = fullName.trim();
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      if (editId) {
        // The update endpoint does not accept a role change, so it is intentionally left out
        // of this payload, see the disabled Role field below.
        await updateFamilyMember(token, editId, {
          full_name: trimmedName,
          relationship,
          date_of_birth: dateOfBirth || undefined,
          gender,
          blood_group: bloodGroup || undefined,
        });
      } else {
        await createFamilyMember(token, {
          full_name: trimmedName,
          relationship,
          role,
          access_level: "full",
          date_of_birth: dateOfBirth || undefined,
          gender,
          blood_group: bloodGroup || undefined,
        });
      }
      // Forces the family list to refetch before it mounts on the next page, so the change
      // shows up right away instead of waiting on SWR's own revalidate-on-mount timing.
      await mutate((key) => typeof key === "string" && key.endsWith(":family-members"));
      showToast({
        message: editId
          ? formatMessage(dm.family.add.updateSuccess, { name: trimmedName })
          : formatMessage(dm.family.add.addSuccess, { name: trimmedName }),
        variant: "success",
      });
      router.push("/dashboard/family");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.family.add.saveError);
      setSubmitting(false);
    }
  }

  const initials = getInitials(fullName);

  if (stillLoadingEditTarget) {
    return (
      <div className="mx-auto max-w-[1400px]">
        <Skeleton className="h-6 w-32" />
        <Skeleton className="mt-4 h-9 w-64" />
        <Skeleton className="mt-2 h-5 w-96" />
        <Skeleton className="mt-8 h-[420px] rounded-2xl" />
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-[1400px]">
      <Link href="/dashboard/family" className="flex items-center gap-2 text-sm font-medium text-ink-muted hover:text-primary">
        <ArrowLeft size={16} /> {dm.family.add.back}
      </Link>

      <PageHeading
        title={isEditing ? dm.family.add.editTitle : dm.family.add.title}
        description={isEditing ? dm.family.add.editDescription : dm.family.add.description}
        action={
          <button
            type="button"
            onClick={() => setInfoOpen(true)}
            aria-label={dm.family.add.infoAria}
            title={dm.family.add.infoAria}
            className="flex h-9 w-9 items-center justify-center rounded-full text-ink-muted transition-colors hover:bg-primary-tint hover:text-primary"
          >
            <Info size={20} />
          </button>
        }
      />

      <RelationRoleInfoModal open={infoOpen} onClose={() => setInfoOpen(false)} dm={dm} />

      <div className="rounded-2xl border border-border bg-card p-6 sm:p-8">
        <form onSubmit={handleSubmit} noValidate>
          {error && (
            <div className="mb-6 flex items-start gap-2.5 rounded-xl border border-error/25 bg-error-bg px-4 py-3 text-sm font-medium text-error">
              <WarningCircle size={18} weight="fill" className="mt-0.5 shrink-0" />
              {error}
            </div>
          )}

          <div className="grid grid-cols-1 gap-8 sm:grid-cols-[150px_1fr]">
            <div className="flex flex-col items-center gap-1 text-center">
              <div className="relative">
                <div className="flex h-[110px] w-[110px] items-center justify-center rounded-full bg-primary text-3xl font-bold text-primary-foreground">
                  {initials}
                </div>
                <span className="absolute -bottom-1 -end-1 flex h-8 w-8 items-center justify-center rounded-full border-2 border-card bg-primary-tint text-primary">
                  <Plus size={16} weight="bold" />
                </span>
              </div>
              <p className="mt-2 text-sm font-semibold text-ink">{dm.family.add.addPhoto}</p>
              <p className="text-xs text-ink-faint">{dm.family.add.addPhotoHint}</p>
            </div>

            <div className="flex flex-col gap-5">
              <div>
                <label htmlFor="fullName" className="block text-sm font-medium text-ink">
                  {dm.family.add.fullName} <span className="text-error">*</span>
                </label>
                <input
                  id="fullName"
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className="mt-1.5 w-full max-w-lg rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>

              <div>
                <label htmlFor="role" className="block text-sm font-medium text-ink">
                  {dm.family.add.role}
                </label>
                <Select
                  id="role"
                  value={role}
                  onChange={(v) => setRole(v as "dependent" | "caregiver")}
                  disabled={isEditing}
                  options={[
                    { value: "dependent", label: dm.family.add.roleDependent },
                    { value: "caregiver", label: dm.family.add.roleCaregiver },
                  ]}
                  className="mt-1.5 max-w-lg"
                />
                {isEditing && (
                  <p className="mt-1.5 text-xs text-ink-faint">{dm.family.add.roleLockedHint}</p>
                )}
              </div>

              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="relationship" className="block text-sm font-medium text-ink">
                    {dm.family.add.relation}
                  </label>
                  <Select
                    id="relationship"
                    value={relationship}
                    onChange={(v) => setRelationship(v as Relation)}
                    options={relations.map((r) => ({ value: r, label: relationLabel(dm, r) }))}
                    className="mt-1.5"
                  />
                </div>
                <div>
                  <label htmlFor="dob" className="block text-sm font-medium text-ink">
                    {dm.family.add.dateOfBirth}
                  </label>
                  <input
                    id="dob"
                    type="date"
                    value={dateOfBirth}
                    onChange={(e) => setDateOfBirth(e.target.value)}
                    className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label htmlFor="gender" className="block text-sm font-medium text-ink">
                    {dm.family.add.gender}
                  </label>
                  <Select
                    id="gender"
                    value={gender}
                    onChange={setGender}
                    options={[
                      { value: "male", label: dm.auth.onboarding.genderOptions.male },
                      { value: "female", label: dm.auth.onboarding.genderOptions.female },
                      { value: "other", label: dm.auth.onboarding.genderOptions.other },
                      { value: "unknown", label: dm.auth.onboarding.genderOptions.unknown },
                    ]}
                    className="mt-1.5"
                  />
                </div>
                <div>
                  <label htmlFor="bloodGroup" className="block text-sm font-medium text-ink">
                    {dm.family.add.bloodGroup}
                  </label>
                  <Select
                    id="bloodGroup"
                    value={bloodGroup}
                    onChange={setBloodGroup}
                    placeholder={dm.family.add.unknown}
                    options={BLOOD_GROUPS.map((bg) => ({ value: bg, label: bg }))}
                    className="mt-1.5"
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="mt-6 flex justify-end">
            <button
              type="submit"
              disabled={submitting}
              className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
            >
              {submitting
                ? isEditing
                  ? dm.family.add.saving
                  : dm.family.add.submitting
                : isEditing
                  ? dm.family.add.saveChanges
                  : dm.family.add.submit}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
