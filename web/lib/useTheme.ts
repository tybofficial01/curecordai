"use client";

import { useCallback, useEffect, useState, useSyncExternalStore } from "react";

export type Theme = "light" | "dark";

export const THEME_STORAGE_KEY = "curecordai-theme";

// Module-level, shared across every component calling useTheme() - without
// this, each call had its own useState that only synced once on its own
// mount, so toggling in the Navbar updated the DOM attribute (and therefore
// every CSS-variable-driven color) instantly, but a second component reading
// theme into React state (e.g. to pick an image) never found out and stayed
// stuck on whatever it was when it first mounted.
const listeners = new Set<() => void>();

function getSnapshot(): Theme {
  return document.documentElement.getAttribute("data-theme") === "light" ? "light" : "dark";
}

// Used only for the SSR render and the first client render before hydration
// reconciles - matches the pre-hydration default the inline script in
// app/layout.tsx corrects before paint.
function getServerSnapshot(): Theme {
  return "dark";
}

function applyTheme(theme: Theme) {
  document.documentElement.setAttribute("data-theme", theme);
  window.localStorage.setItem(THEME_STORAGE_KEY, theme);
  listeners.forEach((listener) => listener());
}

function subscribe(callback: () => void) {
  listeners.add(callback);
  return () => listeners.delete(callback);
}

export function useTheme() {
  const liveTheme = useSyncExternalStore(subscribe, getSnapshot, getServerSnapshot);

  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);
  const theme = mounted ? liveTheme : getServerSnapshot();

  const toggleTheme = useCallback(() => {
    applyTheme(getSnapshot() === "dark" ? "light" : "dark");
  }, []);

  const setTheme = useCallback((next: Theme) => {
    applyTheme(next);
  }, []);

  return { theme, toggleTheme, setTheme };
}
