"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { flushSync } from "react-dom";
import { mutate as globalMutate } from "swr";
import { apiFetch, errorFromPayload } from "@/lib/api/client";
import type { AuthUser, MeOut } from "@/lib/api/types";

interface TokenIssuedPayload {
  user?: AuthUser;
  access_token?: string;
  expires_at?: string;
}

interface AuthContextValue {
  user: AuthUser | null;
  isLoading: boolean;
  isSignedIn: boolean;
  getAccessToken: () => Promise<string | null>;
  applySession: (payload: TokenIssuedPayload) => void;
  refreshUser: () => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

async function postJson<T>(path: string, body: unknown): Promise<T> {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body ?? {}),
    credentials: "same-origin",
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw errorFromPayload(response.status, payload, "Request failed");
  }
  return payload as T;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<AuthUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const accessTokenRef = useRef<string | null>(null);
  const expiresAtRef = useRef<number>(0);
  const refreshPromiseRef = useRef<Promise<string | null> | null>(null);

  const applySession = useCallback((payload: TokenIssuedPayload) => {
    if (payload.access_token) accessTokenRef.current = payload.access_token;
    if (payload.expires_at) expiresAtRef.current = new Date(payload.expires_at).getTime();
    // Callers navigate (router.push) right after this returns, often into a route that shares
    // this same AuthProvider instance (e.g. signup -> onboarding). flushSync forces the isSignedIn
    // update to commit before that navigation renders, so the destination route doesn't briefly
    // see stale (signed-out) context and bounce back to the sign-in/sign-up page.
    if (payload.user) {
      const user = payload.user;
      flushSync(() => setUser(user));
    }
  }, []);

  const clearSession = useCallback(() => {
    accessTokenRef.current = null;
    expiresAtRef.current = 0;
    setUser(null);
    // Drop every cached resource (medications, family members, records, ...) so the next
    // account to sign in in this tab never renders stale data left behind by the previous one.
    globalMutate(() => true, undefined, { revalidate: false });
  }, []);

  const refreshUser = useCallback(async () => {
    const token = accessTokenRef.current;
    if (!token) return;
    const me = await apiFetch<MeOut>("/users/me", { token });
    // See applySession: flush synchronously so a router.push right after this resolves
    // never races a navigation against this state commit.
    flushSync(() =>
      setUser({
        id: me.id,
        phone_number: me.phone_number,
        email: me.email,
        auth_provider: me.auth_provider,
        is_active: me.is_active,
        is_email_verified: me.is_email_verified,
        is_phone_verified: me.is_phone_verified,
        data_region: me.data_region,
        created_at: me.created_at,
      })
    );
  }, []);

  const performRefresh = useCallback(async (): Promise<string | null> => {
    try {
      const payload = await postJson<TokenIssuedPayload>("/api/auth/refresh", {});
      applySession(payload);
      return payload.access_token ?? null;
    } catch {
      clearSession();
      return null;
    }
  }, [applySession, clearSession]);

  const getAccessToken = useCallback(async (): Promise<string | null> => {
    const nearExpiry = expiresAtRef.current - Date.now() < 30_000;
    if (accessTokenRef.current && !nearExpiry) {
      return accessTokenRef.current;
    }
    if (!refreshPromiseRef.current) {
      refreshPromiseRef.current = performRefresh().finally(() => {
        refreshPromiseRef.current = null;
      });
    }
    return refreshPromiseRef.current;
  }, [performRefresh]);

  const signOut = useCallback(async () => {
    const token = accessTokenRef.current;
    try {
      await fetch("/api/auth/logout", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify({}),
        credentials: "same-origin",
      });
    } finally {
      clearSession();
    }
  }, [clearSession]);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const token = await performRefresh();
      if (!cancelled && token) {
        await refreshUser().catch(() => clearSession());
      }
      if (!cancelled) setIsLoading(false);
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <AuthContext.Provider
      value={{
        user,
        isLoading,
        isSignedIn: Boolean(user),
        getAccessToken,
        applySession,
        refreshUser,
        signOut,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
