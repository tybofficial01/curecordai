import { createNavigation } from "next-intl/navigation";
import { routing } from "@/i18n/routing";

// Locale-aware Link/router/pathname helpers for the marketing site - these
// automatically prepend/strip the "/en" | "/ur" | "/roman-ur" URL segment so
// in-app navigation between marketing pages preserves whichever locale the
// visitor is currently reading in.
export const { Link, redirect, usePathname, useRouter, getPathname } = createNavigation(routing);
