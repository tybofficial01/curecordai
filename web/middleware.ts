import createMiddleware from "next-intl/middleware";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { routing } from "@/i18n/routing";

const intlMiddleware = createMiddleware(routing);

// Paths that live outside the locale-prefixed marketing site: the
// authenticated webapp, auth flows, doctor-facing share pages, the
// coming-soon page itself, and API routes. These never go through
// next-intl's locale routing.
const APP_PATH_PREFIXES = ["/dashboard", "/auth", "/share", "/coming-soon", "/api"];

function isAppPath(pathname: string) {
  return APP_PATH_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`));
}

export default function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const appPath = isAppPath(pathname);

  if (process.env.APP_LOCKED === "true" && appPath) {
    if (pathname.startsWith("/api/")) {
      return NextResponse.json(
        { detail: "Service temporarily unavailable" },
        {
          status: 503,
          headers: { "Cache-Control": "no-store", "X-Robots-Tag": "noindex, nofollow" },
        }
      );
    }

    // Doctor-facing QR share links and the coming-soon page itself must
    // stay reachable even while the rest of the app is locked.
    if (!pathname.startsWith("/share/") && pathname !== "/coming-soon") {
      const url = request.nextUrl.clone();
      url.pathname = "/coming-soon";
      const response = NextResponse.redirect(url);
      response.headers.set("Cache-Control", "no-store");
      response.headers.set("X-Robots-Tag", "noindex, nofollow");
      return response;
    }
  }

  return appPath ? NextResponse.next() : intlMiddleware(request);
}

export const config = {
  // Everything except Next internals, Vercel internals, and requests for
  // static files (which contain a dot) goes through this middleware - both
  // the locale-prefixed marketing site and the app paths above.
  matcher: ["/((?!_next|_vercel|.*\\..*).*)"],
};
