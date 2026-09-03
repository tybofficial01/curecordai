import { useTranslations } from "next-intl";
import { Check } from "@phosphor-icons/react/dist/ssr";
import { Button } from "@/components/ui/Button";
import { pricingPlans } from "@/content/pricing";

export function PricingPlans() {
  const t = useTranslations("pricing");

  return (
    <div className="grid gap-8 sm:grid-cols-2">
      {pricingPlans.map((plan) => {
        const features = t.raw(`plans.${plan.key}.features`) as string[];

        return (
          <div
            key={plan.key}
            className={`flex flex-col rounded-2xl border p-8 ${
              plan.highlighted ? "border-primary shadow-lg" : "border-border"
            }`}
          >
            {plan.highlighted && (
              <span className="mb-4 w-fit rounded-full bg-primary-tint px-3 py-1 text-xs font-semibold text-primary">
                {t("mostPopular")}
              </span>
            )}
            <h3 className="text-xl font-semibold text-ink">{t(`plans.${plan.key}.name`)}</h3>
            <p className="mt-3 flex items-baseline gap-2">
              <span className="text-4xl font-bold text-ink">{t(`plans.${plan.key}.price`)}</span>
              <span className="text-sm text-ink-muted">{t(`plans.${plan.key}.period`)}</span>
            </p>
            <p className="mt-2 text-sm text-ink-muted">{t(`plans.${plan.key}.description`)}</p>
            <ul className="mt-6 flex flex-1 flex-col gap-3">
              {features.map((feature) => (
                <li key={feature} className="flex items-start gap-2 text-sm text-ink">
                  <Check size={18} weight="bold" className="mt-0.5 shrink-0 text-primary" />
                  {feature}
                </li>
              ))}
            </ul>
            <Button
              href="/auth/signup"
              variant={plan.highlighted ? "primary" : "secondary"}
              className="mt-8 w-full"
            >
              {t(`plans.${plan.key}.cta`)}
            </Button>
          </div>
        );
      })}
    </div>
  );
}
