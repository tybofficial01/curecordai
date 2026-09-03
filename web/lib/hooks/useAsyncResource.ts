"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useAuth } from "@/lib/auth/AuthContext";

/** Fetches a resource with the current access token, re-running whenever `deps` change. */
export function useAsyncResource<T>(
  fetcher: (token: string) => Promise<T>,
  deps: unknown[] = []
) {
  const { getAccessToken } = useAuth();
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  // Guards against out-of-order responses: if `deps` change again (e.g. navigating vault/[id] to
  // vault/[id2]) before the previous fetch resolves, a slower earlier request must not overwrite
  // the newer one's result.
  const requestIdRef = useRef(0);
  // Tracks whether we already have data, so background refetches (e.g. status polling)
  // don't flip isLoading back to true and flash the loading skeleton on every poll.
  const hasDataRef = useRef(false);

  const refetch = useCallback(async () => {
    const requestId = ++requestIdRef.current;
    if (!hasDataRef.current) setIsLoading(true);
    setError(null);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error("Not signed in");
      const result = await fetcher(token);
      if (requestIdRef.current !== requestId) return;
      hasDataRef.current = true;
      setData(result);
    } catch (err) {
      if (requestIdRef.current !== requestId) return;
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      if (requestIdRef.current === requestId) setIsLoading(false);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  useEffect(() => {
    // A new `refetch` identity means `deps` changed (e.g. navigating to a different record),
    // so this is a fresh resource and should show the loading skeleton again.
    hasDataRef.current = false;
    refetch();
  }, [refetch]);

  return { data, isLoading, error, refetch, setData };
}
