"use client";

import { useEffect, useRef, useState, type ReactNode } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { List, X, SignOut, CaretDown, TextIndent, FirstAidKit } from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";
import { useAuth } from "@/lib/auth/AuthContext";
import { getUnreadAlertCount } from "@/lib/api/alerts";
import { primaryNavItems, secondaryNavItems, accountNavItems } from "@/lib/dashboard-nav";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { ThemeToggle } from "@/components/ui/ThemeToggle";
import { ProfileSwitcher } from "@/components/dashboard/ProfileSwitcher";
import { Popover } from "@/components/ui/Popover";
import { Skeleton } from "@/components/dashboard/Skeleton";

function NavLink({
  href,
  label,
  icon: IconComponent,
  pathname,
  unreadAlerts,
  collapsed,
  onNavigate,
}: {
  href: string;
  label: string;
  icon: Icon;
  pathname: string;
  unreadAlerts: number;
  collapsed?: boolean;
  onNavigate?: () => void;
}) {
  const isActive = pathname === href;
  return (
    <Link
      href={href}
      title={collapsed ? label : undefined}
      onClick={onNavigate}
      className={`flex items-center gap-2.5 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors lg:py-2 ${
        collapsed ? "justify-center px-2" : ""
      } ${isActive ? "bg-primary-tint text-primary" : "text-ink-muted hover:bg-surface hover:text-ink"}`}
    >
      <IconComponent size={20} weight={isActive ? "fill" : "regular"} />
      {!collapsed && label}
      {!collapsed && href === "/dashboard/alerts" && unreadAlerts > 0 && (
        <span className="flex h-5 min-w-5 items-center justify-center rounded-full bg-error px-1 text-xs font-semibold text-primary-foreground">
          {unreadAlerts}
        </span>
      )}
    </Link>
  );
}

// Mirrors the signed-in shell's layout (sidebar + top bar + content area) so auth resolving
// on first load reads as "already loading" instead of a blank/spinner interstitial.
function DashboardShellSkeleton() {
  return (
    <div className="min-h-screen bg-surface lg:flex">
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col gap-6 border-e border-border bg-card p-6 lg:flex">
        <Skeleton className="h-7 w-36" />
        <Skeleton className="h-9 w-full" />
        <div className="flex flex-1 flex-col gap-2">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-9 w-full" />
          ))}
        </div>
        <Skeleton className="h-10 w-full" />
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="flex items-center justify-between border-b border-border bg-card px-4 py-3 lg:hidden">
          <Skeleton className="h-6 w-32" />
          <Skeleton className="h-8 w-8 rounded-full" />
        </header>

        <div className="mx-auto w-full max-w-7xl px-4 pb-24 pt-6 sm:px-8 sm:pt-8 lg:pb-8">
          <Skeleton className="h-6 w-48" />
          <Skeleton className="mt-2 h-4 w-72" />
          <div className="mt-8 flex flex-col gap-3">
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-20" />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function AccountMenu({
  open,
  setOpen,
  expanded,
  popoverPlacement,
  identityLabel,
  avatarInitial,
  onSignOut,
  dm,
}: {
  open: boolean;
  setOpen: (value: boolean | ((v: boolean) => boolean)) => void;
  expanded: boolean;
  popoverPlacement: "up" | "down";
  identityLabel: string;
  avatarInitial: string;
  onSignOut: () => void;
  dm: ReturnType<typeof useDashboardMessages>;
}) {
  const triggerRef = useRef<HTMLButtonElement>(null);
  return (
    <div className="relative">
      <button
        ref={triggerRef}
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-label={dm.common.accountMenu}
        aria-expanded={open}
        className={
          expanded
            ? "flex w-full items-center gap-3 rounded-xl px-2 py-2 text-start hover:bg-surface"
            : "flex items-center gap-2 rounded-full py-1 ps-1 pe-2 text-sm font-medium text-ink hover:bg-surface"
        }
      >
        <span
          className={`flex ${expanded ? "h-9 w-9" : "h-8 w-8"} shrink-0 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-foreground`}
        >
          {avatarInitial}
        </span>
        {expanded && <span className="min-w-0 flex-1 truncate text-sm font-medium text-ink">{identityLabel}</span>}
        <CaretDown size={14} className={expanded ? "shrink-0 text-ink-muted" : "hidden text-ink-muted sm:block"} />
      </button>

      {/* Rendered through a portal (position: fixed, viewport-clamped) instead of an absolutely
          positioned child - the sidebar/header are narrow, direction-flipping containers and a
          locally-positioned popover would either get clipped by their overflow or run off the
          edge of the screen in RTL layouts. */}
      <Popover
        open={open}
        onClose={() => setOpen(false)}
        triggerRef={triggerRef}
        align={popoverPlacement === "up" ? "start" : "end"}
        side={popoverPlacement === "up" ? "top" : "bottom"}
        className="w-64 p-2"
      >
        <p className="truncate px-3 py-2 text-sm font-semibold text-ink">{identityLabel}</p>
        <div className="border-t border-border pt-1">
          {accountNavItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => setOpen(false)}
              className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-ink-muted hover:bg-surface hover:text-ink"
            >
              <item.icon size={18} />
              {dm.nav[item.navKey]}
            </Link>
          ))}
          <button
            type="button"
            onClick={onSignOut}
            className="flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-error hover:bg-error/10"
          >
            <SignOut size={18} /> {dm.nav.signOut}
          </button>
        </div>
      </Popover>
    </div>
  );
}

// Next.js layouts cannot receive props from the pages they wrap, so a page specific content
// width override has to be keyed off the route here instead of passed in as a prop. Every route
// not listed here keeps the exact default width behavior.
const WIDE_CONTENT_ROUTES = ["/dashboard/family/add"];

export function DashboardShell({ children }: { children: ReactNode }) {
  const { user, isLoading, isSignedIn, getAccessToken, signOut } = useAuth();
  const dm = useDashboardMessages();
  const router = useRouter();
  const pathname = usePathname();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [sidebarMenuOpen, setSidebarMenuOpen] = useState(false);
  const [mobileAccountMenuOpen, setMobileAccountMenuOpen] = useState(false);
  const [drawerAccountMenuOpen, setDrawerAccountMenuOpen] = useState(false);
  const [unreadAlerts, setUnreadAlerts] = useState(0);

  useEffect(() => {
    if (!isLoading && !isSignedIn) {
      router.replace("/auth/signin");
    }
  }, [isLoading, isSignedIn, router]);

  useEffect(() => {
    setMobileMenuOpen(false);
    setSidebarMenuOpen(false);
    setMobileAccountMenuOpen(false);
    setDrawerAccountMenuOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!isSignedIn) return;
    let cancelled = false;
    (async () => {
      const token = await getAccessToken();
      if (!token || cancelled) return;
      try {
        const { unread_count } = await getUnreadAlertCount(token);
        if (!cancelled) setUnreadAlerts(unread_count);
      } catch {
        // Non-critical - badge just stays at its last known value.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [isSignedIn, pathname, getAccessToken]);

  async function handleSignOut() {
    await signOut();
    router.replace("/auth/signin");
  }

  if (isLoading || !isSignedIn || !user) {
    return <DashboardShellSkeleton />;
  }

  const identityLabel = user.email ?? user.phone_number ?? dm.common.yourAccount;
  const avatarInitial = identityLabel.charAt(0).toUpperCase();
  const isEmergencyActive = pathname === "/dashboard/emergency";
  const hasWideContent = WIDE_CONTENT_ROUTES.includes(pathname);
  // The default cap (max-w-7xl, or 1600px with the sidebar collapsed) is looser than the space
  // actually available next to the sidebar on most laptop screens, so it rarely binds there.
  // Wide content routes drop it entirely and also trim the desktop side padding a bit, since
  // that is the part of the shell that is actually eating into the available width at those
  // sizes, so a page like this one gets every extra pixel the layout can reasonably spare.
  const contentMaxWidthClassName = hasWideContent ? "max-w-none" : sidebarCollapsed ? "max-w-[1600px]" : "max-w-7xl";
  const mainPaddingClassName = hasWideContent ? "px-4" : "px-4 sm:px-8";

  return (
    <div className="min-h-screen bg-surface lg:flex">
      {/* Desktop sidebar - everything lives in one scannable column instead of a two-row
          top bar, with Emergency pinned in its own footer slot so it's never more than
          a glance away regardless of how many other nav items the app grows to. */}
      <aside
        className={`sticky top-0 hidden h-screen shrink-0 flex-col border-e border-border bg-card lg:flex ${
          sidebarCollapsed ? "w-20" : "w-64"
        }`}
      >
        <div className={`flex items-center py-5 ${sidebarCollapsed ? "justify-center px-2" : "justify-between px-6"}`}>
          {!sidebarCollapsed && (
            <Link href="/dashboard" className="text-xl font-bold text-primary">
              CurecordAI
            </Link>
          )}
          <button
            type="button"
            onClick={() => setSidebarCollapsed((v) => !v)}
            aria-label={sidebarCollapsed ? dm.common.expandSidebar : dm.common.collapseSidebar}
            className="rounded-lg p-1.5 text-ink-muted hover:bg-surface hover:text-ink"
          >
            <TextIndent size={20} className={sidebarCollapsed ? "rotate-180" : ""} />
          </button>
        </div>

        <div className="pb-3">
          <ProfileSwitcher collapsed={sidebarCollapsed} />
        </div>
        <div className="mx-3 mb-2 border-t border-border" />

        <nav className="flex flex-1 flex-col gap-1 overflow-y-auto px-3" aria-label={dm.shell.primaryNav}>
          {primaryNavItems.map((item) => (
            <NavLink
              key={item.href}
              {...item}
              label={dm.nav[item.navKey]}
              pathname={pathname}
              unreadAlerts={unreadAlerts}
              collapsed={sidebarCollapsed}
              onNavigate={() => setSidebarCollapsed(true)}
            />
          ))}
          <div className="my-2 border-t border-border" />
          {secondaryNavItems.map((item) => (
            <NavLink
              key={item.href}
              {...item}
              label={dm.nav[item.navKey]}
              pathname={pathname}
              unreadAlerts={unreadAlerts}
              collapsed={sidebarCollapsed}
              onNavigate={() => setSidebarCollapsed(true)}
            />
          ))}
        </nav>

        <div className="border-t border-border p-3">
          <Link
            href="/dashboard/emergency"
            title={sidebarCollapsed ? dm.nav.emergency : undefined}
            onClick={() => setSidebarCollapsed(true)}
            className={`flex items-center gap-2.5 rounded-xl border px-3 py-2.5 text-sm font-semibold transition-colors ${
              sidebarCollapsed ? "justify-center px-2" : ""
            } ${isEmergencyActive ? "border-error bg-error/10 text-error" : "border-error/40 text-error hover:bg-error/10"}`}
          >
            <FirstAidKit size={20} weight={isEmergencyActive ? "fill" : "bold"} /> {!sidebarCollapsed && dm.nav.emergency}
          </Link>
        </div>

        <div className={`flex border-t border-border p-3 ${sidebarCollapsed ? "flex-col items-center gap-2" : "items-center gap-2"}`}>
          <div className={sidebarCollapsed ? "" : "min-w-0 flex-1"}>
            <AccountMenu
              open={sidebarMenuOpen}
              setOpen={setSidebarMenuOpen}
              expanded={!sidebarCollapsed}
              popoverPlacement="up"
              identityLabel={identityLabel}
              avatarInitial={avatarInitial}
              onSignOut={handleSignOut}
              dm={dm}
            />
          </div>
          <ThemeToggle size={22} />
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col lg:min-h-0">
        {/* Mobile top bar */}
        <header className="sticky top-0 z-40 flex items-center justify-between border-b border-border bg-card/70 px-4 py-3 backdrop-blur-lg lg:hidden">
          <Link href="/dashboard" className="text-lg font-bold text-primary">
            CurecordAI
          </Link>
          <div className="flex items-center gap-1">
            {/* No Emergency icon here - Emergency is a native-app-only feature and is not
                functional in the web browser experience, so it is left out of the mobile
                header entirely (unlike the desktop sidebar, which keeps it). */}
            <ThemeToggle />
            <AccountMenu
              open={mobileAccountMenuOpen}
              setOpen={setMobileAccountMenuOpen}
              expanded={false}
              popoverPlacement="down"
              identityLabel={identityLabel}
              avatarInitial={avatarInitial}
              onSignOut={handleSignOut}
              dm={dm}
            />
            <button
              type="button"
              onClick={() => setMobileMenuOpen((v) => !v)}
              aria-label={mobileMenuOpen ? dm.common.closeMenu : dm.common.openMenu}
              aria-expanded={mobileMenuOpen}
              className="rounded-lg p-2 text-ink"
            >
              {mobileMenuOpen ? <X size={24} /> : <List size={24} />}
            </button>
          </div>
        </header>

        {/* Mobile nav drawer backdrop - closes the drawer on an outside tap. No effect at lg
            since the drawer is never opened there (the hamburger button only exists below lg). */}
        {mobileMenuOpen && (
          <div
            className="fixed inset-0 z-40 bg-black/40 lg:hidden"
            onClick={() => setMobileMenuOpen(false)}
            aria-hidden="true"
          />
        )}

        {/* Mobile nav drawer - mirrors the desktop sidebar's content and order (account switcher,
            primary nav, secondary nav, Emergency, account menu) so the two never drift apart. */}
        <aside
          className={`fixed inset-y-0 left-0 z-50 flex w-[85vw] max-w-xs -translate-x-full flex-col overflow-y-auto bg-card p-4 shadow-xl transition-transform duration-300 ease-in-out lg:hidden ${
            mobileMenuOpen ? "translate-x-0" : ""
          }`}
        >
          <div className="mb-3 flex items-center justify-between">
            <Link href="/dashboard" className="text-lg font-bold text-primary" onClick={() => setMobileMenuOpen(false)}>
              CurecordAI
            </Link>
            <button
              type="button"
              onClick={() => setMobileMenuOpen(false)}
              aria-label={dm.common.closeMenu}
              className="flex h-9 w-9 items-center justify-center rounded-full text-ink-muted hover:bg-surface hover:text-ink"
            >
              <X size={20} />
            </button>
          </div>

          <ProfileSwitcher />
          <div className="my-3 border-t border-border" />

          <nav className="flex flex-col gap-1" aria-label={dm.shell.primaryNav}>
            {primaryNavItems.map((item) => (
              <NavLink
                key={item.href}
                {...item}
                label={dm.nav[item.navKey]}
                pathname={pathname}
                unreadAlerts={unreadAlerts}
                onNavigate={() => setMobileMenuOpen(false)}
              />
            ))}
            <div className="my-2 border-t border-border" />
            {secondaryNavItems.map((item) => (
              <NavLink
                key={item.href}
                {...item}
                label={dm.nav[item.navKey]}
                pathname={pathname}
                unreadAlerts={unreadAlerts}
                onNavigate={() => setMobileMenuOpen(false)}
              />
            ))}
          </nav>

          <div className="mt-3 border-t border-border pt-3">
            <Link
              href="/dashboard/emergency"
              onClick={() => setMobileMenuOpen(false)}
              className={`flex items-center gap-2.5 rounded-xl border px-3 py-2.5 text-sm font-semibold transition-colors ${
                isEmergencyActive ? "border-error bg-error/10 text-error" : "border-error/40 text-error hover:bg-error/10"
              }`}
            >
              <FirstAidKit size={20} weight={isEmergencyActive ? "fill" : "bold"} /> {dm.nav.emergency}
            </Link>
          </div>

          <div className="mt-3 flex items-center gap-2 border-t border-border pt-3">
            <div className="min-w-0 flex-1">
              <AccountMenu
                open={drawerAccountMenuOpen}
                setOpen={setDrawerAccountMenuOpen}
                expanded
                popoverPlacement="up"
                identityLabel={identityLabel}
                avatarInitial={avatarInitial}
                onSignOut={handleSignOut}
                dm={dm}
              />
            </div>
            <ThemeToggle size={22} />
          </div>
        </aside>

        <div className={`mx-auto w-full lg:flex lg:min-h-0 lg:flex-1 lg:flex-col ${contentMaxWidthClassName}`}>
          <main
            className={`min-w-0 overflow-x-hidden ${mainPaddingClassName} pb-8 pt-6 sm:pt-8 lg:flex lg:min-h-0 lg:flex-1 lg:flex-col`}
          >
            {children}
          </main>
        </div>
      </div>
    </div>
  );
}
