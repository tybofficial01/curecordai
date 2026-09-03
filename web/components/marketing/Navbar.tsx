"use client";

import { useEffect, useState } from "react";
import NextLink from "next/link";
import { useLocale, useTranslations } from "next-intl";
import { List, X, UserCircle } from "@phosphor-icons/react/dist/ssr";
import { marketingNavLinks } from "@/content/site";
import { ThemeToggle } from "@/components/ui/ThemeToggle";
import { LanguageSwitcher } from "@/components/marketing/LanguageSwitcher";
import { scrollToSection } from "@/lib/scrollToSection";
import { Link, usePathname } from "@/i18n/navigation";
import type { AppLocale } from "@/i18n/routing";

// Shared classes for every link/button that sits directly on the glass —
// nav items, Home, and Sign In all read through this so the hover/active
// glass treatment (see .glass-navbar-item in globals.css) never drifts
// between them.
const navItemBase = "glass-navbar-item rounded-full px-3.5 py-2 text-sm font-medium lg:px-4";

export function Navbar() {
  const [open, setOpen] = useState(false);
  const [activeSection, setActiveSection] = useState<string | null>(null);
  const pathname = usePathname();
  const locale = useLocale() as AppLocale;
  const t = useTranslations("nav");

  const navItems = [
    { href: "/", labelKey: "home" as const },
    ...marketingNavLinks,
  ];

  const sectionIds = marketingNavLinks
    .filter((link) => link.href.startsWith("/#"))
    .map((link) => link.href.slice(2));

  // Scroll-spy: only meaningful on the homepage, where these section ids
  // actually exist. A section is "active" once it's scrolled to just below
  // the sticky header, within the top third of the viewport.
  useEffect(() => {
    if (pathname !== "/") return;

    function updateActiveSection() {
      const headerHeight = document.querySelector("header")?.getBoundingClientRect().height ?? 0;
      let current: string | null = null;
      for (const id of sectionIds) {
        const el = document.getElementById(id);
        if (!el) continue;
        if (el.getBoundingClientRect().top - headerHeight <= window.innerHeight * 0.3) {
          current = id;
        }
      }
      setActiveSection(current);
    }

    updateActiveSection();
    window.addEventListener("scroll", updateActiveSection, { passive: true });
    window.addEventListener("resize", updateActiveSection);
    return () => {
      window.removeEventListener("scroll", updateActiveSection);
      window.removeEventListener("resize", updateActiveSection);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  // Arriving at the homepage with a hash already in the URL - either from a
  // cross-page nav click (Link already navigated to "/#id") or a shared/
  // bookmarked link - scrolls to that section with the same smooth animation
  // used for in-page clicks, instead of the browser's default instant jump.
  useEffect(() => {
    if (pathname !== "/") return;
    const hash = window.location.hash.slice(1);
    if (!hash) return;
    const frame = requestAnimationFrame(() => scrollToSection(hash));
    return () => cancelAnimationFrame(frame);
  }, [pathname]);

  function handleNavClick(e: React.MouseEvent, href: string) {
    if (!href.startsWith("/#")) return;
    // Already on the homepage: intercept and animate instead of letting the
    // browser jump instantly. From any other page, let Link navigate to
    // "/#id" normally (client-side route change) - the effect above takes
    // over once the homepage has mounted.
    if (pathname !== "/") return;
    e.preventDefault();
    scrollToSection(href.slice(2));
  }

  function isLinkActive(href: string) {
    const sectionId = href.startsWith("/#") ? href.slice(2) : null;
    return sectionId ? pathname === "/" && activeSection === sectionId : pathname === href;
  }

  return (
    <header className="sticky top-0 z-50 h-20">
      <div className="animate-navbar-in mx-auto flex h-full w-full max-w-6xl items-center px-4 sm:px-6">
        <nav
          aria-label={t("primary")}
          className="glass-navbar flex h-14 w-full items-center justify-between gap-1 rounded-full px-3 sm:h-16 sm:px-4 lg:px-5"
        >
          <Link href="/" locale={locale} className="shrink-0 px-2 text-lg font-bold text-primary sm:text-xl">
            CurecordAI
          </Link>

          <div className="hidden items-center gap-0.5 md:flex">
            {navItems.map((link) => {
              const isActive = isLinkActive(link.href);
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  locale={locale}
                  onClick={(e) => handleNavClick(e, link.href)}
                  aria-current={isActive ? "page" : undefined}
                  data-active={isActive || undefined}
                  className={`${navItemBase} ${
                    isActive
                      ? "text-[rgb(var(--navbar-fg-rgb))]"
                      : "text-[rgb(var(--navbar-fg-rgb)/0.65)] hover:text-[rgb(var(--navbar-fg-rgb))]"
                  }`}
                >
                  {t(link.labelKey)}
                </Link>
              );
            })}
          </div>

          <div className="hidden items-center gap-1.5 md:flex">
            <LanguageSwitcher />
            <ThemeToggle />
            <NextLink
              href="/auth/signin"
              aria-label={t("signIn")}
              className={`${navItemBase} flex items-center gap-1.5 text-[rgb(var(--navbar-fg-rgb)/0.65)] hover:text-[rgb(var(--navbar-fg-rgb))]`}
            >
              <UserCircle size={20} weight="regular" />
              {t("signIn")}
            </NextLink>
            <NextLink
              href="/auth/signup"
              className="rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground shadow-[0_0_20px_-4px_rgb(var(--color-primary-rgb)/0.55)] transition-colors hover:bg-primary/90"
            >
              {t("getStarted")}
            </NextLink>
          </div>

          <div className="flex items-center gap-0.5 md:hidden">
            <ThemeToggle />
            <button
              type="button"
              onClick={() => setOpen((v) => !v)}
              className="glass-navbar-item flex items-center justify-center rounded-full p-2 text-[rgb(var(--navbar-fg-rgb)/0.8)] hover:text-[rgb(var(--navbar-fg-rgb))]"
              aria-label={open ? t("closeMenu") : t("openMenu")}
              aria-expanded={open}
            >
              {open ? <X size={24} /> : <List size={24} />}
            </button>
          </div>
        </nav>
      </div>

      {open && (
        <div className="px-4 sm:px-6 md:hidden">
          <nav
            aria-label={t("mobile")}
            className="glass-navbar animate-navbar-in mx-auto flex max-w-6xl flex-col gap-1 rounded-3xl p-3"
          >
            {navItems.map((link) => {
              const isActive = isLinkActive(link.href);
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  locale={locale}
                  onClick={(e) => {
                    handleNavClick(e, link.href);
                    setOpen(false);
                  }}
                  aria-current={isActive ? "page" : undefined}
                  data-active={isActive || undefined}
                  className={`glass-navbar-item rounded-2xl px-4 py-3 text-base font-medium ${
                    isActive
                      ? "text-[rgb(var(--navbar-fg-rgb))]"
                      : "text-[rgb(var(--navbar-fg-rgb)/0.7)]"
                  }`}
                >
                  {t(link.labelKey)}
                </Link>
              );
            })}
            <div className="mt-2 flex items-center border-t border-[rgb(var(--navbar-fg-rgb)/0.1)] px-1 pt-4">
              <LanguageSwitcher />
            </div>
            <div className="flex flex-col gap-3 px-1 pt-2">
              <NextLink
                href="/auth/signin"
                onClick={() => setOpen(false)}
                className="text-base font-medium text-[rgb(var(--navbar-fg-rgb)/0.7)]"
              >
                {t("signIn")}
              </NextLink>
              <NextLink
                href="/auth/signup"
                onClick={() => setOpen(false)}
                className="rounded-full bg-primary px-5 py-3 text-center text-base font-semibold text-primary-foreground"
              >
                {t("getStarted")}
              </NextLink>
            </div>
          </nav>
        </div>
      )}
    </header>
  );
}
