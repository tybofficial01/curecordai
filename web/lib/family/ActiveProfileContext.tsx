"use client";

import { createContext, useContext, useMemo, useState, type ReactNode } from "react";
import type { FamilyMember } from "@/lib/api/types";

// Mirrors the mobile app's ActiveProfile model (fe/lib/features/family/providers/active_profile_provider.dart)
// - client-only, in-memory, resets on reload. There's no backend concept of a "currently active"
// family member; every API call is just scoped by an explicit family_member_id per request.
export interface ActiveProfile {
  isOwnerMode: boolean;
  memberId: string | null;
  memberName: string | null;
  memberRelationship: string | null;
  memberPhotoUrl: string | null;
}

const OWNER_PROFILE: ActiveProfile = {
  isOwnerMode: true,
  memberId: null,
  memberName: null,
  memberRelationship: null,
  memberPhotoUrl: null,
};

interface ActiveProfileContextValue {
  profile: ActiveProfile;
  switchToOwner: () => void;
  switchToMember: (member: FamilyMember) => void;
}

const ActiveProfileContext = createContext<ActiveProfileContextValue | null>(null);

export function ActiveProfileProvider({ children }: { children: ReactNode }) {
  const [profile, setProfile] = useState<ActiveProfile>(OWNER_PROFILE);

  const value = useMemo<ActiveProfileContextValue>(
    () => ({
      profile,
      switchToOwner: () => setProfile(OWNER_PROFILE),
      switchToMember: (member: FamilyMember) =>
        setProfile({
          isOwnerMode: false,
          memberId: member.id,
          memberName: member.full_name,
          memberRelationship: member.relationship,
          memberPhotoUrl: member.photo_url,
        }),
    }),
    [profile]
  );

  return <ActiveProfileContext.Provider value={value}>{children}</ActiveProfileContext.Provider>;
}

export function useActiveProfile(): ActiveProfileContextValue {
  const ctx = useContext(ActiveProfileContext);
  if (!ctx) throw new Error("useActiveProfile must be used within ActiveProfileProvider");
  return ctx;
}
