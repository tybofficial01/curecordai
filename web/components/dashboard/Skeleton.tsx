// `bg-border` (not `bg-surface`) on purpose: the page background and `bg-surface` share the exact
// same color in both themes (see globals.css), so a `bg-surface` block would render invisibly on
// top of it - indistinguishable from a blank screen. `bg-border` is the nearest token with real
// contrast against the page background in both light and dark themes.
export function Skeleton({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-xl bg-border ${className}`} />;
}
