"use client";

import { useSyncThemeWithAccount } from "@/lib/theme/useSyncThemeWithAccount";

/** Invisible - reconciles html[data-theme] with the signed-in user's saved preference. */
export function ThemeAccountSync() {
  useSyncThemeWithAccount();
  return null;
}
