import { useTranslations } from "next-intl";
import { Container } from "@/components/ui/Container";
import { FolderSimple, ChatCircleText, ShareNetwork, Check } from "@phosphor-icons/react/dist/ssr";

const solutions = [
  { key: "vault", icon: FolderSimple },
  { key: "explain", icon: ChatCircleText },
  { key: "share", icon: ShareNetwork },
] as const;

export function SolutionSection() {
  const t = useTranslations("home");

  return (
    <section className="bg-surface py-16 sm:py-20">
      <Container>
        <div className="mx-auto max-w-2xl text-center">
          <h2 className="text-3xl font-bold tracking-tight text-ink sm:text-4xl">{t("solutionHeading")}</h2>
        </div>
        <div className="mt-12 grid gap-8 lg:grid-cols-3">
          {solutions.map((solution) => (
            <div key={solution.key} className="flex flex-col items-start">
              <span className="flex h-12 w-12 items-center justify-center rounded-full bg-primary-tint text-primary">
                <solution.icon size={24} weight="bold" />
              </span>
              <h3 className="mt-4 text-lg font-semibold text-ink">{t(`solutions.${solution.key}.title`)}</h3>
              <p className="mt-2 text-sm leading-relaxed text-ink-muted">
                {t(`solutions.${solution.key}.description`)}
              </p>
              <span className="mt-3 flex items-center gap-1.5 text-sm font-medium text-success">
                <Check size={16} weight="bold" /> {t("solutionIncluded")}
              </span>
            </div>
          ))}
        </div>
      </Container>
    </section>
  );
}
