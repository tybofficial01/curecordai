import { useTranslations } from "next-intl";
import NextLink from "next/link";
import { DeviceMobile, AppleLogo, GlobeSimple } from "@phosphor-icons/react/dist/ssr";
import { Container } from "@/components/ui/Container";
import { footerLinkGroups, socialLinks } from "@/content/site";
import { Link } from "@/i18n/navigation";

// /auth/* routes live outside the locale-prefixed marketing route tree (see
// architecture note in i18n/routing.ts), so they must use the plain Next
// Link - the locale-aware Link would otherwise incorrectly prepend
// "/en" | "/ur" | "/roman-ur" to them.
function isUnprefixedRoute(href: string) {
  return href.startsWith("/auth/");
}

export function Footer() {
  const t = useTranslations("footer");

  return (
    <footer className="border-t border-border bg-surface">
      <Container className="py-12 sm:py-14">
        <div className="flex flex-col gap-10 lg:flex-row lg:items-start lg:justify-between lg:gap-16">
          <div className="max-w-xs">
            <p className="text-xl font-bold text-primary">CurecordAI</p>
            <p className="mt-3 text-sm text-ink-muted">{t("tagline")}</p>
            <div className="mt-5 flex flex-wrap gap-2.5">
              <span className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-2 text-xs font-medium text-ink-muted">
                <DeviceMobile size={16} /> {t("android")}
              </span>
              <span className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-2 text-xs font-medium text-ink-muted">
                <AppleLogo size={16} /> {t("ios")}
              </span>
              <span className="flex items-center gap-2 rounded-lg border border-border bg-card px-3 py-2 text-xs font-medium text-ink-muted">
                <GlobeSimple size={16} /> {t("web")}
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-x-6 gap-y-10 sm:grid-cols-4 sm:gap-x-10">
            {footerLinkGroups.map((group) => (
              <div key={group.headingKey}>
                <p className="text-sm font-semibold text-ink">{t(`groups.${group.headingKey}`)}</p>
                <ul className="mt-4 flex flex-col gap-3">
                  {group.links.map((link) => {
                    const LinkComponent = isUnprefixedRoute(link.href) ? NextLink : Link;
                    return (
                      <li key={link.href}>
                        <LinkComponent href={link.href} className="text-sm text-ink-muted hover:text-primary">
                          {t(`links.${link.labelKey}`)}
                        </LinkComponent>
                      </li>
                    );
                  })}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </Container>

      <div className="border-t border-border">
        <Container className="flex flex-col-reverse items-center gap-4 py-6 sm:flex-row sm:justify-between">
          <p className="text-xs text-ink-muted">
            &copy; {new Date().getFullYear()} {t("copyright")}
          </p>
          <div className="flex flex-wrap justify-center gap-x-5 gap-y-2">
            {socialLinks.map((social) => (
              <a
                key={social.href}
                href={social.href}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs font-medium text-ink-muted hover:text-primary"
              >
                {social.label}
              </a>
            ))}
          </div>
        </Container>
      </div>
    </footer>
  );
}
