import { useTranslations } from "next-intl";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";

export function CTABanner({
  title,
  description,
}: {
  /** Optional page-specific (already translated) override for the default "cta.*" copy. */
  title?: string;
  description?: string;
}) {
  const t = useTranslations();

  return (
    <section className="bg-primary-dark py-16 sm:py-20">
      <Container className="flex flex-col items-center gap-6 text-center">
        <h2 className="max-w-2xl text-3xl font-bold text-white sm:text-4xl">
          {title ?? t("cta.title")}
        </h2>
        <p className="max-w-xl text-lg text-white/90">{description ?? t("cta.description")}</p>
        <div className="flex flex-col gap-3 sm:flex-row">
          <Button href="/auth/signup" variant="secondary" className="!bg-white !text-primary hover:!bg-white/90">
            {t("common.getStartedFree")}
          </Button>
          <Button href="/how-it-works" variant="ghost" className="!border-white/40 !text-white hover:!bg-white/10">
            {t("common.seeHowItWorks")}
          </Button>
        </div>
      </Container>
    </section>
  );
}
