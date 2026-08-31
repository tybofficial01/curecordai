"use client";

import { useRef, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { CaretDown, Check, Plus } from "@phosphor-icons/react/dist/ssr";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { getProfile } from "@/lib/api/profile";
import { listFamilyMembers } from "@/lib/api/family";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { Popover } from "@/components/ui/Popover";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";
import type { FamilyMember } from "@/lib/api/types";

async function loadSwitcherData(token: string) {
  const [profile, members] = await Promise.all([getProfile(token), listFamilyMembers(token)]);
  return { profile, members };
}

function Avatar({ photoUrl, name, active }: { photoUrl: string | null; name: string; active?: boolean }) {
  const [failed, setFailed] = useState(false);
  return (
    <span
      className={`flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full text-xs font-bold ${
        active ? "bg-primary text-primary-foreground" : "bg-primary-tint text-primary"
      }`}
    >
      {photoUrl && !failed ? (
        <Image
          src={photoUrl}
          alt={name}
          width={32}
          height={32}
          className="h-full w-full object-cover"
          onError={() => setFailed(true)}
        />
      ) : (
        name.charAt(0).toUpperCase() || "?"
      )}
    </span>
  );
}

function Row({
  photoUrl,
  name,
  subtitle,
  active,
  onClick,
}: {
  photoUrl: string | null;
  name: string;
  subtitle: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex w-full items-center gap-3 rounded-lg px-3 py-2 text-start transition-colors ${
        active ? "bg-primary-tint" : "hover:bg-surface"
      }`}
    >
      <Avatar photoUrl={photoUrl} name={name} active={active} />
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-semibold text-ink">{name}</span>
        <span className="block truncate text-xs text-ink-muted">{subtitle}</span>
      </span>
      {active && <Check size={16} weight="bold" className="shrink-0 text-primary" />}
    </button>
  );
}

export function ProfileSwitcher({ collapsed = false }: { collapsed?: boolean }) {
  const dm = useDashboardMessages();
  const { data } = useCachedResource("profile-switcher", loadSwitcherData, { revalidateOnFocus: true });
  const { profile: active, switchToOwner, switchToMember } = useActiveProfile();
  const [open, setOpen] = useState(false);
  const triggerRef = useRef<HTMLButtonElement>(null);

  if (!data) {
    return (
      <div
        className={collapsed ? "mx-auto h-9 w-9 animate-pulse rounded-full bg-surface" : "mx-3 h-12 animate-pulse rounded-xl bg-surface"}
      />
    );
  }

  const currentName = active.isOwnerMode ? data.profile.full_name : (active.memberName ?? dm.common.member);
  const currentPhoto = active.isOwnerMode ? data.profile.profile_photo_url : active.memberPhotoUrl;
  const currentSubtitle = active.isOwnerMode ? dm.common.owner : (active.memberRelationship ?? dm.common.familyMember);

  function selectMember(member: FamilyMember) {
    switchToMember(member);
    setOpen(false);
  }

  function selectOwner() {
    switchToOwner();
    setOpen(false);
  }

  return (
    <div className={collapsed ? "flex justify-center" : "mx-3"}>
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-label={dm.common.switchProfile}
        aria-expanded={open}
        title={collapsed ? currentName : undefined}
        className={
          collapsed
            ? "rounded-full hover:opacity-80"
            : "flex w-full items-center gap-2.5 rounded-xl px-2 py-2 text-start hover:bg-surface"
        }
      >
        <Avatar photoUrl={currentPhoto} name={currentName} />
        {!collapsed && (
          <>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-semibold text-ink">{currentName}</span>
              <span className="block truncate text-xs text-ink-muted">{currentSubtitle}</span>
            </span>
            <CaretDown size={14} className="shrink-0 text-ink-muted" />
          </>
        )}
      </button>

      <Popover open={open} onClose={() => setOpen(false)} triggerRef={triggerRef} align="start" side="bottom" className="w-72 p-2">
        <p className="px-3 py-1.5 text-xs font-medium text-ink-faint">{dm.common.switchProfile}</p>

        <Row
          photoUrl={data.profile.profile_photo_url}
          name={data.profile.full_name}
          subtitle={dm.common.ownerYou}
          active={active.isOwnerMode}
          onClick={selectOwner}
        />

        {data.members.map((member) => (
          <Row
            key={member.id}
            photoUrl={member.photo_url}
            name={member.full_name}
            subtitle={member.relationship}
            active={!active.isOwnerMode && active.memberId === member.id}
            onClick={() => selectMember(member)}
          />
        ))}

        <div className="my-1 border-t border-border" />

        <Link
          href="/dashboard/family/add"
          onClick={() => setOpen(false)}
          className="flex w-full items-center gap-3 rounded-lg px-3 py-2 text-start hover:bg-surface"
        >
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground">
            <Plus size={16} weight="bold" />
          </span>
          <span className="text-sm font-medium text-ink">{dm.common.addFamilyMember}</span>
        </Link>
      </Popover>
    </div>
  );
}
