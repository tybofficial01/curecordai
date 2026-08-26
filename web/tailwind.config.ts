import type { Config } from "tailwindcss";

// Reads the "R G B" channel variable defined in globals.css and lets Tailwind
// inject an alpha channel for opacity-modifier utilities (e.g. bg-primary/10).
function withOpacity(variable: string) {
  return ({ opacityValue }: { opacityValue?: string }) =>
    opacityValue === undefined ? `rgb(var(${variable}))` : `rgb(var(${variable}) / ${opacityValue})`;
}

// Tailwind's shipped types don't model the function-based "opacity value" color
// recipe (documented in Tailwind's own color customization guide), so this object
// is intentionally left untyped until the final cast below.
const config = {
  content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}", "./lib/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        background: withOpacity("--color-background-rgb"),
        surface: withOpacity("--color-surface-rgb"),
        card: withOpacity("--color-card-rgb"),
        elevated: withOpacity("--color-elevated-rgb"),
        primary: {
          DEFAULT: withOpacity("--color-primary-rgb"),
          dark: withOpacity("--color-primary-dark-rgb"),
          light: withOpacity("--color-primary-light-rgb"),
          tint: withOpacity("--color-primary-tint-rgb"),
          "tint-subtle": withOpacity("--color-primary-tint-subtle-rgb"),
          foreground: withOpacity("--color-primary-foreground-rgb"),
        },
        ink: {
          DEFAULT: withOpacity("--color-ink-rgb"),
          muted: withOpacity("--color-ink-muted-rgb"),
          faint: withOpacity("--color-ink-faint-rgb"),
        },
        border: withOpacity("--color-border-rgb"),
        highlight: withOpacity("--color-highlight-rgb"),
        info: withOpacity("--color-info-rgb"),
        error: withOpacity("--color-error-rgb"),
        "error-bg": withOpacity("--color-error-bg-rgb"),
        success: withOpacity("--color-success-rgb"),
        warning: withOpacity("--color-warning-rgb"),
        "warning-bg": withOpacity("--color-warning-bg-rgb"),
        "warning-dark": withOpacity("--color-warning-dark-rgb"),
        disabled: withOpacity("--color-disabled-rgb"),
        "bubble-ai": withOpacity("--color-bubble-ai-rgb"),
      },
      fontFamily: {
        sans: ["var(--font-manrope)"],
      },
      borderRadius: {
        xl: "1rem",
        "2xl": "1.25rem",
      },
    },
  },
  plugins: [],
};

export default config as unknown as Config;
