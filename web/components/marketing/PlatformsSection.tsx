import { useTranslations } from "next-intl";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";
import { DeviceMobile, AppleLogo, GlobeSimple } from "@phosphor-icons/react/dist/ssr";

// Platform names stay in Latin script in every locale (they're product names);
// the availability note under each is translated.
const platforms = [
  { icon: DeviceMobile, labelKey: "android", noteKey: "comingSoon" },
  { icon: AppleLogo, labelKey: "ios", noteKey: "comingSoon" },
  { icon: GlobeSimple, labelKey: "web", noteKey: "webNote" },
] as const;

export function PlatformsSection() {
  const t = useTranslations();

  return (
    <section className="py-16 sm:py-20">
      <Container className="text-center">
        <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">
          {t("platforms.heading")}
        </h2>
        <p className="mx-auto mt-3 max-w-xl text-lg text-ink-muted">{t("platforms.body")}</p>
        <div className="mt-10 grid gap-6 sm:grid-cols-3">
          {platforms.map((platform) => (
            <div
              key={platform.labelKey}
              className="flex flex-col items-center gap-3 rounded-2xl border border-border p-8"
            >
              <platform.icon size={36} className="text-primary" weight="duotone" />
              <p className="text-base font-semibold text-ink">{t(`footer.${platform.labelKey}`)}</p>
              <p className="text-sm text-ink-muted">{t(`platforms.${platform.noteKey}`)}</p>
            </div>
          ))}
        </div>
        <div className="mt-10">
          <Button href="/auth/signup">{t("common.getStartedFree")}</Button>
        </div>
      </Container>
    </section>
  );
}
