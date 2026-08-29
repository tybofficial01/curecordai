"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { Icon } from "@phosphor-icons/react";
import {
  UsersThree,
  Trash,
  PencilSimple,
  Info,
  Plus,
  X,
  Key,
  IdentificationCard,
  QrCode,
  UserCircle,
  Heart,
  Baby,
} from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useConfirm } from "@/lib/dialog/ConfirmDialogProvider";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";
import { deleteFamilyMember, listFamilyMembers } from "@/lib/api/family";
import type { FamilyMember } from "@/lib/api/types";
import { Skeleton } from "@/components/dashboard/Skeleton";

// Small fixed palette of existing theme tokens (no new colors) so family members are visually
// distinguishable from each other in the grid rather than all sharing the same teal avatar.
const AVATAR_PALETTES = [
  "bg-primary-tint text-primary",
  "bg-info/15 text-info",
  "bg-success/15 text-success",
  "bg-warning/15 text-warning",
];

function avatarPaletteFor(name: string): string {
  let hash = 0;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 31 + name.charCodeAt(i)) >>> 0;
  }
  return AVATAR_PALETTES[hash % AVATAR_PALETTES.length];
}

const HOW_IT_WORKS_ICONS: Icon[] = [Key, IdentificationCard, UsersThree, QrCode];

function FamilyHowItWorksModal({
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
        aria-labelledby="family-how-it-works-title"
        className="max-h-[90vh] w-full max-w-lg overflow-y-auto rounded-2xl border border-border bg-card p-6 shadow-lg"
      >
        <div className="flex items-start justify-between gap-4">
          <h2 id="family-how-it-works-title" className="text-base font-semibold text-ink">
            {dm.family.howItWorksTitle}
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
          {dm.family.howItWorksItems.map((item, index) => {
            const ItemIcon = HOW_IT_WORKS_ICONS[index];
            return (
              <div key={item.title} className="flex flex-col gap-2 rounded-xl border border-border bg-surface p-4">
                <span className="flex h-9 w-9 items-center justify-center rounded-full bg-primary-tint text-primary">
                  <ItemIcon size={18} />
                </span>
                <p className="text-sm font-semibold text-ink">{item.title}</p>
                <p className="text-xs leading-relaxed text-ink-muted">{item.description}</p>
              </div>
            );
          })}
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

const ADD_FAMILY_SHORTCUTS: { icon: Icon; accent: string; relation: string }[] = [
  { icon: UserCircle, accent: "bg-info/15 text-info", relation: "Parent" },
  { icon: Heart, accent: "bg-primary/15 text-primary", relation: "Spouse" },
  { icon: Baby, accent: "bg-success/15 text-success", relation: "Child" },
];

export default function FamilyPage() {
  const { getAccessToken } = useAuth();
  const confirm = useConfirm();
  const router = useRouter();
  const { switchToMember } = useActiveProfile();
  const dm = useDashboardMessages();
  const { data: members, isLoading, error, setData } = useCachedResource("family-members", listFamilyMembers);
  const [removeError, setRemoveError] = useState("");
  const [howItWorksOpen, setHowItWorksOpen] = useState(false);

  function viewMember(member: FamilyMember) {
    switchToMember(member);
    router.push("/dashboard");
  }

  async function handleRemove(id: string, name: string) {
    const confirmed = await confirm({
      title: formatMessage(dm.family.removeConfirmTitle, { name }),
      description: dm.family.removeConfirmDescription,
      confirmLabel: dm.common.remove,
      cancelLabel: dm.common.cancel,
      destructive: true,
    });
    if (!confirmed) return;
    setRemoveError("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.notSignedIn);
      await deleteFamilyMember(token, id);
      setData((prev) => prev?.filter((m) => m.id !== id) ?? prev);
    } catch (err) {
      setRemoveError(
        err instanceof Error ? err.message : formatMessage(dm.family.removeError, { name })
      );
    }
  }

  return (
    <div>
      {/* Inlined rather than using the shared PageHeading component, which stacks the action
          below the title on narrow screens - that left the info icon floating alone in empty
          space under the description on mobile. Keeping the row unconditional (no flex-col
          fallback) puts the icon directly next to the heading at every width, matching the
          desktop layout and the same fix applied to the AI Health Assistant page. */}
      <div className="mb-8 flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-ink sm:text-3xl">{dm.family.title}</h1>
          <p className="mt-1 text-sm text-ink-muted">{dm.family.description}</p>
        </div>
        <button
          type="button"
          onClick={() => setHowItWorksOpen(true)}
          aria-label={dm.family.howItWorksAria}
          title={dm.family.howItWorksAria}
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-ink-muted transition-colors hover:bg-primary-tint hover:text-primary"
        >
          <Info size={20} />
        </button>
      </div>

      <FamilyHowItWorksModal open={howItWorksOpen} onClose={() => setHowItWorksOpen(false)} dm={dm} />

      {isLoading && (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 3 }).map((_, i) => (
            <Skeleton key={i} className="h-32" />
          ))}
        </div>
      )}
      {error && <p className="text-sm text-error">{error}</p>}
      {removeError && <p className="text-sm text-error">{removeError}</p>}

      {members && (
        members.length === 0 ? (
          <>
            <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-border bg-card px-6 py-10 text-center">
              <span className="flex h-14 w-14 items-center justify-center rounded-full bg-primary-tint text-primary">
                <UsersThree size={28} weight="duotone" />
              </span>
              <h2 className="text-lg font-semibold text-ink">{dm.family.emptyTitle}</h2>
              <p className="max-w-sm text-sm text-ink-muted">{dm.family.emptyDescription}</p>
              <Link
                href="/dashboard/family/add"
                className="mt-1 rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              >
                {dm.family.addMember}
              </Link>
            </div>
            <div className="mt-6 grid grid-cols-1 gap-3 sm:grid-cols-3">
              {ADD_FAMILY_SHORTCUTS.map((shortcut, index) => {
                const copy = dm.family.addShortcuts[index];
                return (
                  <Link
                    key={shortcut.relation}
                    href={`/dashboard/family/add?relation=${shortcut.relation}`}
                    className="rounded-2xl border border-border bg-card p-3.5 transition-colors hover:border-primary hover:bg-primary-tint/40 sm:p-4"
                  >
                    <span className={`flex h-10 w-10 items-center justify-center rounded-xl sm:h-11 sm:w-11 ${shortcut.accent}`}>
                      <shortcut.icon size={20} weight="bold" />
                    </span>
                    <p className="mt-3.5 text-sm font-bold text-ink">{copy.title}</p>
                    <p className="mt-0.5 text-xs text-ink-muted">{copy.description}</p>
                  </Link>
                );
              })}
            </div>
          </>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <Link
              href="/dashboard/family/add"
              className="flex flex-col items-center justify-center gap-2 rounded-2xl border border-dashed border-border bg-card/50 p-5 text-center transition-colors hover:border-primary hover:bg-card/70"
            >
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary-tint/70 text-primary">
                <Plus size={22} weight="bold" />
              </span>
              <p className="text-sm font-semibold text-ink-muted">{dm.common.addFamilyMember}</p>
            </Link>

            {members.map((member) => (
              <div
                key={member.id}
                role="button"
                tabIndex={0}
                onClick={() => viewMember(member)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" || event.key === " ") {
                    event.preventDefault();
                    viewMember(member);
                  }
                }}
                className="flex cursor-pointer flex-col gap-4 rounded-2xl border border-border bg-card p-5 text-start transition-colors hover:border-primary"
              >
                <div className="flex items-center gap-3">
                  <span
                    className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-full text-lg font-semibold ${avatarPaletteFor(member.full_name)}`}
                  >
                    {member.full_name.charAt(0)}
                  </span>
                  <div className="min-w-0">
                    <p className="truncate text-sm font-semibold text-ink">{member.full_name}</p>
                    <p className="text-xs text-ink-muted capitalize">{member.relationship}</p>
                  </div>
                </div>

                {/* Every card always shows all three rows, with a muted placeholder for
                    anything not provided, so cards line up at the same height regardless
                    of how much data a given family member has. */}
                <div className="flex flex-col gap-1.5 text-xs">
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink-muted">{dm.family.fieldGender}</span>
                    <span className={member.gender ? "capitalize text-ink" : "text-ink-faint"}>
                      {member.gender ?? dm.family.notProvided}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink-muted">{dm.family.fieldBloodGroup}</span>
                    <span className={member.blood_group ? "text-ink" : "text-ink-faint"}>
                      {member.blood_group ?? dm.family.notProvided}
                    </span>
                  </div>
                  <div className="flex items-center justify-between gap-2">
                    <span className="text-ink-muted">{dm.family.fieldAge}</span>
                    <span className={member.age !== null ? "text-ink" : "text-ink-faint"}>
                      {member.age !== null ? formatMessage(dm.family.yearsOld, { age: member.age }) : dm.family.notProvided}
                    </span>
                  </div>
                </div>

                <div className="flex items-center justify-end gap-4 border-t border-border pt-3">
                  <Link
                    href={`/dashboard/family/add?edit=${member.id}`}
                    onClick={(event) => event.stopPropagation()}
                    aria-label={formatMessage(dm.family.editAria, { name: member.full_name })}
                    className="flex items-center gap-1.5 max-lg:py-2.5 text-xs font-medium text-ink-muted hover:text-primary"
                  >
                    <PencilSimple size={14} /> {dm.common.edit}
                  </Link>
                  <button
                    type="button"
                    onClick={(event) => {
                      event.stopPropagation();
                      handleRemove(member.id, member.full_name);
                    }}
                    aria-label={formatMessage(dm.family.removeAria, { name: member.full_name })}
                    className="flex items-center gap-1.5 max-lg:py-2.5 text-xs font-medium text-error hover:underline"
                  >
                    <Trash size={14} /> {dm.common.remove}
                  </button>
                </div>
              </div>
            ))}
          </div>
        )
      )}
    </div>
  );
}
