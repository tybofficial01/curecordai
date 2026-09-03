import { useTranslations } from "next-intl";
import { howItWorksSteps } from "@/content/how-it-works";

export function HowItWorksSteps() {
  const t = useTranslations("howItWorks");

  return (
    <div className="grid gap-10 sm:grid-cols-3">
      {howItWorksSteps.map((item) => (
        <div key={item.key} className="relative text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full bg-primary text-primary-foreground">
            <item.icon size={28} weight="bold" />
          </div>
          <p className="mt-4 text-sm font-semibold text-primary">
            {t("stepLabel", { number: item.step })}
          </p>
          <h3 className="mt-1 text-xl font-semibold text-ink">{t(`steps.${item.key}.title`)}</h3>
          <p className="mt-2 text-sm leading-relaxed text-ink-muted">
            {t(`steps.${item.key}.description`)}
          </p>
        </div>
      ))}
    </div>
  );
}
