import {
  House,
  UploadSimple,
  FolderSimple,
  ChatCircleDots,
  UsersThree,
  QrCode,
  ChartBar,
  Bell,
  FirstAidKit,
  UserCircle,
  Pill,
} from "@phosphor-icons/react/dist/ssr";

// `navKey` looks up the matching label in lib/locale/dashboardMessages.ts's "nav" namespace
// (see components/dashboard/DashboardShell.tsx) so sidebar/tab-bar labels follow the signed-in
// user's language preference; `label` stays as the English fallback/default. Deliberately named
// `navKey` rather than `key` - these objects get spread with {...item} onto JSX elements
// elsewhere, and a plain `key` property would collide with React's special `key` prop.
export type NavKey = keyof ReturnType<typeof import("@/lib/locale/dashboardMessages").useDashboardMessages>["nav"];

// Primary row: the destinations used every visit. Listed first in both the desktop sidebar
// and the mobile nav drawer.
export const primaryNavItems = [
  { href: "/dashboard", label: "Dashboard", navKey: "dashboard" as const, icon: House },
  { href: "/dashboard/upload", label: "Upload", navKey: "upload" as const, icon: UploadSimple },
  { href: "/dashboard/vault", label: "Health Vault", navKey: "vault" as const, icon: FolderSimple },
  { href: "/dashboard/assistant", label: "AI Assistant", navKey: "assistant" as const, icon: ChatCircleDots },
  { href: "/dashboard/family", label: "Family", navKey: "family" as const, icon: UsersThree },
  { href: "/dashboard/medications", label: "Medications", navKey: "medications" as const, icon: Pill },
];

// Secondary: less frequent actions, grouped below the primary items in the sidebar and
// the mobile nav drawer.
export const secondaryNavItems = [
  { href: "/dashboard/share", label: "Share with Doctor", navKey: "share" as const, icon: QrCode },
  { href: "/dashboard/insights", label: "Insights", navKey: "insights" as const, icon: ChartBar },
  { href: "/dashboard/alerts", label: "Alerts", navKey: "alerts" as const, icon: Bell },
];

// Pinned separately from every other list - an emergency contact needs to be reachable in one
// tap from anywhere, not buried behind a "more" menu, so it gets its own fixed slot in the
// sidebar footer and the mobile header instead of competing for space in a nav list.
export const emergencyNavItem = {
  href: "/dashboard/emergency",
  label: "Emergency",
  navKey: "emergency" as const,
  icon: FirstAidKit,
};

export const accountNavItems = [
  { href: "/dashboard/profile", label: "Profile & Settings", navKey: "profile" as const, icon: UserCircle },
];

export const dashboardNavItems = [...primaryNavItems, ...secondaryNavItems, emergencyNavItem, ...accountNavItems];
