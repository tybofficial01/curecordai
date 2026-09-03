import { siteConfig } from "@/content/site";

interface ArticleSchemaProps {
  title: string;
  description: string;
  publishedAt: string;
  updatedAt: string;
  slug: string;
  authorName: string;
}

export default function ArticleSchema({
  title,
  description,
  publishedAt,
  updatedAt,
  slug,
  authorName,
}: ArticleSchemaProps) {
  const schema = {
    "@context": "https://schema.org",
    "@type": "Article",
    headline: title,
    description,
    author: {
      "@type": "Person",
      name: authorName,
    },
    publisher: {
      "@type": "Organization",
      name: "CurecordAI",
      logo: {
        "@type": "ImageObject",
        url: `${siteConfig.url}/logo.png`,
      },
    },
    datePublished: publishedAt,
    dateModified: updatedAt,
    url: `${siteConfig.url}/blog/${slug}`,
    mainEntityOfPage: {
      "@type": "WebPage",
      "@id": `${siteConfig.url}/blog/${slug}`,
    },
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}
