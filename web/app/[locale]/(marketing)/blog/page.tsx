import type { Metadata } from "next";
import { getTranslations } from "next-intl/server";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { PageHero } from "@/components/marketing/PageHero";
import { Container } from "@/components/ui/Container";
import { Link } from "@/i18n/navigation";
import { siteConfig } from "@/content/site";
import { getAllPosts, formatPostDate, localize } from "@/content/blog";
import { localeToHtmlLang } from "@/i18n/language";

import { routing } from "@/i18n/routing";

type Props = { params: Promise<{ locale: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "blog.meta" });

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/blog`])
  );

  return {
    title: t("title"),
    description: t("description"),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/blog`,
      languages,
    },
    openGraph: {
      title: "CurecordAI Blog",
      description: t("description"),
      url: `${siteConfig.url}/${locale}/blog`,
      images: [
        {
          url: siteConfig.ogImage,
          width: 1200,
          height: 630,
          alt: "CurecordAI Blog - guides for organizing and understanding family health records",
        },
      ],
    },
  };
}

export default async function BlogIndexPage({ params }: Props) {
  const { locale } = await params;
  const t = await getTranslations({ locale, namespace: "blog" });
  const posts = getAllPosts();

  return (
    <>
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "Blog", url: `${siteConfig.url}/${locale}/blog` },
        ]}
      />
      <PageHero eyebrow={t("eyebrow")} title={t("title")} description={t("description")} />
      <section className="py-16 sm:py-20">
        <Container>
          <div className="grid gap-8 sm:grid-cols-2">
            {posts.map((post) => (
              <article key={post.slug} className="rounded-2xl border border-border p-6">
                <p className="text-xs font-semibold uppercase tracking-wide text-primary">
                  {localize(post.category, locale)}
                </p>
                <h2 className="mt-3 text-xl font-semibold text-ink" lang={localeToHtmlLang[locale as keyof typeof localeToHtmlLang] ?? "en"}>
                  <Link href={`/blog/${post.slug}`} className="hover:text-primary">
                    {localize(post.title, locale)}
                  </Link>
                </h2>
                <p
                  className="mt-2 text-sm leading-relaxed text-ink-muted"
                  lang={localeToHtmlLang[locale as keyof typeof localeToHtmlLang] ?? "en"}
                >
                  {localize(post.excerpt, locale)}
                </p>
                <div className="mt-4 flex items-center justify-between">
                  <time dateTime={post.publishedAt} className="text-xs text-ink-faint">
                    {formatPostDate(post.publishedAt, locale)}
                  </time>
                  <Link
                    href={`/blog/${post.slug}`}
                    className="text-sm font-medium text-primary hover:underline"
                  >
                    {t("readArticle")}
                  </Link>
                </div>
              </article>
            ))}
          </div>
        </Container>
      </section>
    </>
  );
}
