import type { Icon } from "@phosphor-icons/react";
import type { ReactNode } from "react";

export function EmptyState({
  icon: IconComponent,
  title,
  description,
  action,
}: {
  icon: Icon;
  title: string;
  description: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-3 rounded-2xl border border-dashed border-border bg-card px-6 py-16 text-center">
      <span className="flex h-14 w-14 items-center justify-center rounded-full bg-primary-tint text-primary">
        <IconComponent size={28} weight="duotone" />
      </span>
      <h2 className="text-lg font-semibold text-ink">{title}</h2>
      <p className="max-w-sm text-sm text-ink-muted">{description}</p>
      {action}
    </div>
  );
}
