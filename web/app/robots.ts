import { MetadataRoute } from "next";
import { siteConfig } from "@/content/site";

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: "*",
        allow: "/",
        // Only the locale-prefixed marketing pages (see app/sitemap.ts) are
        // meant to be crawled. Everything below is either private or has no
        // search intent, and each also carries its own `robots: noindex`
        // metadata (app/dashboard/layout.tsx, app/auth/layout.tsx,
        // app/share/[token]/layout.tsx) so a crawler that ignores robots.txt
        // still gets told not to index it.
        //
        // /share in particular is the doctor-facing, token-addressed view of a
        // patient's medical history - never relax this.
        disallow: ["/dashboard", "/auth", "/share", "/api/", "/admin", "/_next/", "/coming-soon"],
      },
    ],
    sitemap: `${siteConfig.url}/sitemap.xml`,
  };
}
