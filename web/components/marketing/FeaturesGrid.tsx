import { useTranslations } from "next-intl";
import { productFeatures } from "@/content/features";

export function FeaturesGrid() {
  const t = useTranslations("features.items");

  return (
    <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
      {productFeatures.map((feature) => (
        <div
          key={feature.key}
          className="rounded-2xl border border-border p-6 transition-shadow hover:shadow-md"
        >
          <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary-tint text-primary">
            <feature.icon size={24} weight="bold" />
          </span>
          <h3 className="mt-4 text-lg font-semibold text-ink">{t(`${feature.key}.title`)}</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">
            {t(`${feature.key}.description`)}
          </p>
        </div>
      ))}
    </div>
  );
}
