import type { Metadata } from "next";
import NextLink from "next/link";
import { notFound } from "next/navigation";
import { getTranslations } from "next-intl/server";
import ArticleSchema from "@/components/seo/ArticleSchema";
import BreadcrumbSchema from "@/components/seo/BreadcrumbSchema";
import { Container } from "@/components/ui/Container";
import { Link } from "@/i18n/navigation";
import { siteConfig } from "@/content/site";
import { routing } from "@/i18n/routing";
import { blogPosts, getPostBySlug, getRelatedPosts, formatPostDate, localize } from "@/content/blog";
import { localeToHtmlLang } from "@/i18n/language";

type Props = { params: Promise<{ locale: string; slug: string }> };

// Only the slug is enumerated here - the locale segment comes from the parent
// app/[locale]/layout.tsx generateStaticParams, and Next combines the two.
export function generateStaticParams() {
  return blogPosts.map((post) => ({ slug: post.slug }));
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { locale, slug } = await params;
  const post = getPostBySlug(slug);
  if (!post) return {};

  const languages = Object.fromEntries(
    routing.locales.map((l) => [l, `${siteConfig.url}/${l}/blog/${slug}`])
  );

  return {
    title: localize(post.title, locale),
    description: localize(post.excerpt, locale),
    alternates: {
      canonical: `${siteConfig.url}/${locale}/blog/${slug}`,
      languages,
    },
    openGraph: {
      title: localize(post.title, locale),
      description: localize(post.excerpt, locale),
      url: `${siteConfig.url}/${locale}/blog/${slug}`,
      type: "article",
      publishedTime: post.publishedAt,
      modifiedTime: post.updatedAt,
      authors: [post.authorName],
    },
  };
}

export default async function BlogPostPage({ params }: Props) {
  const { locale, slug } = await params;
  const post = getPostBySlug(slug);
  if (!post) notFound();

  const t = await getTranslations({ locale, namespace: "blog" });
  const tCommon = await getTranslations({ locale, namespace: "common" });
  const related = getRelatedPosts(post.slug);
  const htmlLang = localeToHtmlLang[locale as keyof typeof localeToHtmlLang] ?? "en";
  const title = localize(post.title, locale);

  return (
    <>
      <ArticleSchema
        title={title}
        description={localize(post.excerpt, locale)}
        publishedAt={post.publishedAt}
        updatedAt={post.updatedAt}
        slug={post.slug}
        authorName={post.authorName}
      />
      <BreadcrumbSchema
        items={[
          { name: "Home", url: siteConfig.url },
          { name: "Blog", url: `${siteConfig.url}/${locale}/blog` },
          { name: title, url: `${siteConfig.url}/${locale}/blog/${post.slug}` },
        ]}
      />
      <article className="py-16 sm:py-20">
        <Container className="max-w-2xl">
          <p className="text-xs font-semibold uppercase tracking-wide text-primary">
            {localize(post.category, locale)}
          </p>
          <h1 className="mt-3 text-4xl font-bold tracking-tight text-ink" lang={htmlLang}>
            {title}
          </h1>
          <div className="mt-4 flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-ink-muted">
            <span>{t("post.writtenBy", { author: post.authorName })}</span>
            <span aria-hidden="true">&middot;</span>
            <time dateTime={post.publishedAt}>
              {t("post.published", { date: formatPostDate(post.publishedAt, locale) })}
            </time>
            {post.updatedAt !== post.publishedAt && (
              <>
                <span aria-hidden="true">&middot;</span>
                <time dateTime={post.updatedAt}>
                  {t("post.updated", { date: formatPostDate(post.updatedAt, locale) })}
                </time>
              </>
            )}
          </div>

          <div className="prose-content mt-10 flex flex-col gap-5" lang={htmlLang}>
            {post.content.map((block, index) => (
              <div key={index}>
                {block.heading && (
                  <h2 className="mb-2 text-xl font-semibold text-ink">{localize(block.heading, locale)}</h2>
                )}
                <p className="text-base leading-relaxed text-ink">{localize(block.body, locale)}</p>
                {block.link && (
                  <Link
                    href={block.link.href}
                    className="mt-2 inline-flex text-sm font-medium text-primary hover:underline"
                  >
                    {localize(block.link.label, locale)} &rarr;
                  </Link>
                )}
              </div>
            ))}
          </div>

          <p className="mt-10 border-t border-border pt-6 text-xs leading-relaxed text-ink-faint">
            {t("post.disclaimer")}
          </p>

          <div className="mt-10 rounded-2xl bg-surface p-6">
            <p className="text-sm font-semibold text-ink">{t("post.ctaTitle")}</p>
            <p className="mt-1 text-sm text-ink-muted">{t("post.ctaBody")}</p>
            {/*
              next/link, not the locale-aware Link: /auth is outside the [locale]
              segment (see middleware.ts) and must not get a locale prefix.
            */}
            <NextLink
              href="/auth/signup"
              className="mt-4 inline-flex rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
            >
              {tCommon("getStartedFree")}
            </NextLink>
          </div>

          {related.length > 0 && (
            <div className="mt-14 border-t border-border pt-10">
              <h2 className="text-lg font-semibold text-ink">{t("post.related")}</h2>
              <ul className="mt-4 flex flex-col gap-3">
                {related.map((relatedPost) => (
                  <li key={relatedPost.slug}>
                    <Link
                      href={`/blog/${relatedPost.slug}`}
                      className="text-sm font-medium text-primary hover:underline"
                      lang={htmlLang}
                    >
                      {localize(relatedPost.title, locale)}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Container>
      </article>
    </>
  );
}
