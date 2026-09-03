import { MetadataRoute } from "next";
import { siteConfig } from "@/content/site";
import { blogPosts } from "@/content/blog";
import { routing } from "@/i18n/routing";

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = siteConfig.url;

  const routes = ["", "/features", "/how-it-works", "/pricing", "/faq", "/about", "/contact", "/privacy", "/blog"];

  // Every marketing route gets one sitemap entry per locale ("/en", "/ur",
  // "/roman-ur"), each carrying hreflang alternates to its sibling locale
  // URLs for the same path - the dashboard/auth routes are intentionally
  // excluded (see app/robots.ts, which already disallows /dashboard).
  const staticPages = routes.flatMap((route) =>
    routing.locales.map((locale) => ({
      url: `${baseUrl}/${locale}${route}`,
      lastModified: new Date(),
      changeFrequency: "monthly" as const,
      priority: route === "" ? 1 : 0.8,
      alternates: {
        languages: Object.fromEntries(routing.locales.map((l) => [l, `${baseUrl}/${l}${route}`])),
      },
    }))
  );

  const blogPages = blogPosts.flatMap((post) =>
    routing.locales.map((locale) => ({
      url: `${baseUrl}/${locale}/blog/${post.slug}`,
      lastModified: new Date(post.updatedAt),
      changeFrequency: "weekly" as const,
      priority: 0.6,
      alternates: {
        languages: Object.fromEntries(
          routing.locales.map((l) => [l, `${baseUrl}/${l}/blog/${post.slug}`])
        ),
      },
    }))
  );

  return [...staticPages, ...blogPages];
}
