"use client";

import useSWR from "swr";
import { useAuth } from "@/lib/auth/AuthContext";

/**
 * Same shape as useAsyncResource, but backed by SWR's shared cache: a page that was already
 * visited renders its last-known data instantly (no blank "Loading..." on revisit) while SWR
 * revalidates in the background. `key` must be stable/unique per distinct resource - pass null
 * to skip fetching (e.g. while a dependency isn't ready yet). Not used for the vault/[id] record
 * poll, which needs every read to be genuinely fresh, never served from cache - see
 * NEXTJS_CACHE_AUDIT.md §7.
 *
 * `revalidateOnFocus` defaults to off (most resources don't need it), but resources that can
 * change from another device - e.g. a profile photo updated from the mobile app - should opt
 * in so switching back to this tab picks up the change instead of showing what was cached at
 * mount.
 */
export function useCachedResource<T>(
  key: string | null,
  fetcher: (token: string) => Promise<T>,
  options?: { revalidateOnFocus?: boolean }
) {
  const { getAccessToken, user } = useAuth();
  // Namespaced by user id so a stale cache entry can never be rendered for the wrong account,
  // even if a sign-out/sign-in happens without going through clearSession's cache flush.
  const scopedKey = key && user ? `${user.id}:${key}` : null;
  const { data, error, isLoading, mutate } = useSWR<T>(
    scopedKey,
    async () => {
      const token = await getAccessToken();
      if (!token) throw new Error("Not signed in");
      return fetcher(token);
    },
    { revalidateOnFocus: options?.revalidateOnFocus ?? false, dedupingInterval: 5000 }
  );

  return {
    data: data ?? null,
    isLoading,
    error: error instanceof Error ? error.message : error ? "Something went wrong" : null,
    refetch: () => mutate(),
    setData: (updater: T | null | ((prev: T | null) => T | null)) =>
      mutate(
        (typeof updater === "function" ? (updater as (prev: T | null) => T | null)(data ?? null) : updater) ??
          undefined,
        { revalidate: false }
      ),
  };
}
