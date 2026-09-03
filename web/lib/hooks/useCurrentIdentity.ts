"use client";

import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { getProfile } from "@/lib/api/profile";
import { listFamilyMembers } from "@/lib/api/family";

async function loadSwitcherData(token: string) {
  const [profile, members] = await Promise.all([getProfile(token), listFamilyMembers(token)]);
  return { profile, members };
}

/**
 * Resolves the currently active profile's display name/photo (owner or family member).
 * Uses the same SWR cache key as ProfileSwitcher, so mounting both costs one network
 * request, not two.
 */
export function useCurrentIdentity() {
  const { data } = useCachedResource("profile-switcher", loadSwitcherData, { revalidateOnFocus: true });
  const { profile: active } = useActiveProfile();

  const name = !data ? "You" : active.isOwnerMode ? data.profile.full_name : (active.memberName ?? "Member");
  const photoUrl = !data ? null : active.isOwnerMode ? data.profile.profile_photo_url : active.memberPhotoUrl;

  return { name, photoUrl, initial: name.charAt(0).toUpperCase() || "?" };
}
