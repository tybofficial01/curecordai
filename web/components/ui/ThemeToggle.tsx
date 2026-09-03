"use client";

import { Moon, Sun } from "@phosphor-icons/react/dist/ssr";
import { useTheme } from "@/lib/useTheme";

export function ThemeToggle({ className = "", size = 20 }: { className?: string; size?: number }) {
  const { theme, toggleTheme } = useTheme();
  const isLight = theme === "light";

  return (
    <button
      type="button"
      onClick={toggleTheme}
      aria-label={isLight ? "Switch to dark mode" : "Switch to light mode"}
      className={`flex items-center justify-center rounded-full p-2 text-ink-muted transition-colors hover:bg-primary-tint hover:text-primary ${className}`}
    >
      {isLight ? <Sun size={size} weight="regular" /> : <Moon size={size} weight="regular" />}
    </button>
  );
}
