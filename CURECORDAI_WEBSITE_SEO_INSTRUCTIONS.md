# CurecordAI Website - SEO and AEO Technical Instructions for Coding Agent

> **Purpose:** This file contains non-negotiable SEO and AEO implementation instructions for the CurecordAI website built in Next.js (App Router). Every item here must be implemented from day one. SEO optimization of actual content (keywords, copy, blog posts) will be handled separately by the human team. This file covers the technical structure the coding agent must follow.

---

## 1. Project Stack

```
Framework:     Next.js 14+ (App Router only, not Pages Router)
Styling:       Tailwind CSS
Deployment:    Vercel
Language:      TypeScript
```

---

## 2. Folder Structure - What to Create

```
app/
  layout.tsx              # Root layout with global metadata, schema, fonts
  page.tsx                # Homepage
  features/
    page.tsx
  how-it-works/
    page.tsx
  pricing/
    page.tsx
  faq/
    page.tsx
  about/
    page.tsx
  contact/
    page.tsx
  privacy/
    page.tsx
  blog/
    page.tsx              # Blog index
    [slug]/
      page.tsx            # Individual blog post (dynamic route)
  sitemap.ts              # Auto-generated sitemap
  robots.ts               # Crawl rules
  not-found.tsx           # Custom 404 page
components/
  seo/
    OrganizationSchema.tsx
    FAQSchema.tsx
    ArticleSchema.tsx
    SoftwareAppSchema.tsx
    BreadcrumbSchema.tsx
public/
  favicon.ico
  logo.png                # 512x512 PNG
  og-default.jpg          # 1200x630 Open Graph default image
```

---

## 3. Root Layout - app/layout.tsx

The root layout must include the following. Do not skip any item.

```tsx
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import OrganizationSchema from '@/components/seo/OrganizationSchema'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  metadataBase: new URL('https://curecordai.com'),
  title: {
    default: 'AI Health Record App for Families | CurecordAI',
    template: '%s | CurecordAI',
  },
  description:
    'CurecordAI organizes your family\'s complete medical history in one place and explains lab reports and complex medical documents in plain Urdu or English. Upload any prescription, report or medical document and ask our AI assistant anything about your health.',
  keywords: [
    'health record app Pakistan',
    'AI health assistant Pakistan',
    'medical records organizer Pakistan',
    'family health app Urdu',
    'lab report explainer Pakistan',
    'digital health record Pakistan',
  ],
  authors: [{ name: 'CurecordAI Team' }],
  creator: 'CurecordAI',
  publisher: 'CurecordAI',
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      'max-video-preview': -1,
      'max-image-preview': 'large',
      'max-snippet': -1,
    },
  },
  openGraph: {
    type: 'website',
    locale: 'en_PK',
    url: 'https://curecordai.com',
    siteName: 'CurecordAI',
    title: 'AI Health Record App for Families | CurecordAI',
    description:
      'Organize your family medical history, understand your lab reports in plain Urdu or English, and share records with any doctor in one tap.',
    images: [
      {
        url: '/og-default.jpg',
        width: 1200,
        height: 630,
        alt: 'CurecordAI - AI Powered Health Records for Families',
      },
    ],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'AI Health Record App for Pakistani Families | CurecordAI',
    description:
      'Organize your family medical history, understand your lab reports in plain Urdu or English, and share records with any doctor in one tap.',
    images: ['/og-default.jpg'],
  },
  alternates: {
    canonical: 'https://curecordai.com',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <OrganizationSchema />
        {children}
      </body>
    </html>
  )
}
```

**Rules for root layout:**
- `metadataBase` must be set or all relative Open Graph URLs will break
- `title.template` ensures every page title automatically appends `| CurecordAI`
- `lang="en"` on the html tag is required for accessibility and crawlers
- Load fonts via `next/font/google` only, never via a `<link>` tag in the head (causes render blocking)
- `OrganizationSchema` component renders global JSON-LD and must be in the root layout so it appears on every page

---

## 4. Metadata - Rules for Every Page

Every page file must export its own `metadata` object. Never rely on the root layout metadata alone for inner pages.

```tsx
// Example: app/faq/page.tsx
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Frequently Asked Questions',
  // Becomes: "Frequently Asked Questions | CurecordAI" via template
  description:
    'Get answers to common questions about CurecordAI - how to upload records, how the AI assistant works, privacy, family management, and WhatsApp access.',
  alternates: {
    canonical: 'https://curecordai.com/faq',
  },
  openGraph: {
    title: 'Frequently Asked Questions | CurecordAI',
    description:
      'Get answers to common questions about CurecordAI - how to upload records, how the AI assistant works, privacy, family management, and WhatsApp access.',
    url: 'https://curecordai.com/faq',
    images: [{ url: '/og-default.jpg', width: 1200, height: 630 }],
  },
}
```

**Rules:**
- Every page must have a unique `title` and `description`. No two pages should share the same values.
- Every page must set `alternates.canonical` to its own absolute URL.
- Title must be under 60 characters (before the template adds `| CurecordAI`).
- Description must be under 160 characters.
- Every page must have `openGraph.url` set to its own absolute URL.

---

## 5. Heading Structure - Rules Per Page

```
H1: Exactly one per page. Must contain the primary keyword for that page.
H2: Use for main sections within the page.
H3: Use for sub-sections within an H2 block.
Never skip levels (no H1 directly to H3).
Never use headings for styling. Use Tailwind classes for font size.
```

In JSX this means:

```tsx
// Correct
<h1 className="text-4xl font-bold">Organize Your Family's Medical Records with AI</h1>

// Wrong - do not use an h2 styled to look like an h1
<h2 className="text-4xl font-bold">...</h2>
```

---

## 6. Image Rules - All Images Must Follow These

```tsx
// Always use Next.js Image component, never plain <img>
import Image from 'next/image'

<Image
  src="/hero-dashboard.png"
  alt="CurecordAI health vault dashboard showing organized family medical records"
  width={1200}
  height={800}
  priority={true}   // Add priority only on above-the-fold images
/>
```

**Rules:**
- Every image must have a descriptive `alt` attribute. Not `alt="image"` or `alt=""` unless purely decorative.
- Images above the fold (hero section) must have `priority={true}` to avoid LCP penalty.
- All images must be in WebP format where possible.
- Maximum image file size: 200KB for hero images, 100KB for content images.
- Never use `fill` without a sized parent container.

---

## 7. Sitemap - app/sitemap.ts

```ts
import { MetadataRoute } from 'next'

export default function sitemap(): MetadataRoute.Sitemap {
  const baseUrl = 'https://curecordai.com'

  // Static pages
  const staticPages = [
    '',
    '/features',
    '/how-it-works',
    '/pricing',
    '/faq',
    '/about',
    '/contact',
    '/privacy',
    '/blog',
  ].map((route) => ({
    url: `${baseUrl}${route}`,
    lastModified: new Date(),
    changeFrequency: 'monthly' as const,
    priority: route === '' ? 1 : 0.8,
  }))

  // Blog posts - fetch from your CMS or data source here
  // const posts = await getBlogPosts()
  // const blogPages = posts.map((post) => ({
  //   url: `${baseUrl}/blog/${post.slug}`,
  //   lastModified: new Date(post.updatedAt),
  //   changeFrequency: 'weekly' as const,
  //   priority: 0.6,
  // }))

  return [...staticPages] // Add blogPages when blog content exists
}
```

---

## 8. Robots - app/robots.ts

```ts
import { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: [
          '/dashboard',
          '/records',
          '/profile',
          '/settings',
          '/api/',
          '/admin',
          '/_next/',
        ],
      },
    ],
    sitemap: 'https://curecordai.com/sitemap.xml',
  }
}
```

**Critical rule:** All pages behind authentication must be in the `disallow` list. Never expose user health data to search crawlers. Add `noindex` meta tags inside authenticated pages as a second layer.

```tsx
// Inside any authenticated page component
export const metadata: Metadata = {
  robots: { index: false, follow: false },
}
```

---

## 9. Schema Markup Components

Create these as reusable components. Each one renders a `<script type="application/ld+json">` tag.

### 9.1 OrganizationSchema - app/components/seo/OrganizationSchema.tsx

```tsx
export default function OrganizationSchema() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'CurecordAI',
    url: 'https://curecordai.com',
    logo: 'https://curecordai.com/logo.png',
    sameAs: [
      'https://www.linkedin.com/company/curecordai',
      // Add Twitter, Instagram when accounts are live
    ],
    contactPoint: {
      '@type': 'ContactPoint',
      contactType: 'customer support',
      availableLanguage: ['English', 'Urdu'],
    },
    areaServed: 'PK',
    description:
      'CurecordAI is an AI powered personal health record system for patients and families in Pakistan.',
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
```

### 9.2 SoftwareAppSchema - app/components/seo/SoftwareAppSchema.tsx

Add this component to the homepage and features page only.

```tsx
export default function SoftwareAppSchema() {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'SoftwareApplication',
    name: 'CurecordAI',
    operatingSystem: 'Android, iOS, Web',
    applicationCategory: 'HealthApplication',
    offers: {
      '@type': 'Offer',
      price: '0',
      priceCurrency: 'PKR',
    },
    description:
      'AI powered personal health record app that organizes family medical history, explains records in plain Urdu or English, and enables one tap doctor sharing.',
    url: 'https://curecordai.com',
    // Add installUrl when app store links are live
    // installUrl: 'https://play.google.com/store/apps/details?id=com.curecordai'
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
```

### 9.3 FAQSchema - app/components/seo/FAQSchema.tsx

Add this component to the FAQ page. Pass the questions and answers as props.

```tsx
interface FAQItem {
  question: string
  answer: string
}

export default function FAQSchema({ faqs }: { faqs: FAQItem[] }) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: faqs.map((faq) => ({
      '@type': 'Question',
      name: faq.question,
      acceptedAnswer: {
        '@type': 'Answer',
        text: faq.answer,
      },
    })),
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
```

**Usage in FAQ page:**

```tsx
// app/faq/page.tsx
import FAQSchema from '@/components/seo/FAQSchema'

const faqs = [
  {
    question: 'What is CurecordAI and how does it work?',
    answer:
      'CurecordAI is an AI powered personal health record app for patients and families in Pakistan. You upload any medical document including prescriptions, lab reports, and discharge summaries. The AI reads the document, extracts medications, diagnoses, and lab results, and organizes everything in one searchable health vault per family member.',
  },
  {
    question: 'Is CurecordAI available on Android and iOS?',
    answer:
      'Yes. CurecordAI is available as an Android app on Google Play, an iOS app on the Apple App Store, and as a website.',
  },
  {
    question: 'Can I use CurecordAI on WhatsApp?',
    answer:
      'Yes. CurecordAI has a WhatsApp AI agent. You can upload documents and ask health questions directly through WhatsApp without downloading a separate app.',
  },
  {
    question: 'How is CurecordAI different from ChatGPT for health questions?',
    answer:
      'ChatGPT can only give generic, population level answers because it has no access to your personal medical records. CurecordAI answers every question based on your own uploaded health history, so answers are specific to your actual diagnoses, medications, and lab results.',
  },
  // Add remaining FAQs here
]

export default function FAQPage() {
  return (
    <>
      <FAQSchema faqs={faqs} />
      <main>
        <h1>Frequently Asked Questions</h1>
        {faqs.map((faq, index) => (
          <div key={index}>
            <h2>{faq.question}</h2>
            <p>{faq.answer}</p>
          </div>
        ))}
      </main>
    </>
  )
}
```

### 9.4 ArticleSchema - app/components/seo/ArticleSchema.tsx

Add to every blog post page.

```tsx
interface ArticleSchemaProps {
  title: string
  description: string
  publishedAt: string
  updatedAt: string
  slug: string
  authorName: string
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
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: title,
    description: description,
    author: {
      '@type': 'Person',
      name: authorName,
    },
    publisher: {
      '@type': 'Organization',
      name: 'CurecordAI',
      logo: {
        '@type': 'ImageObject',
        url: 'https://curecordai.com/logo.png',
      },
    },
    datePublished: publishedAt,
    dateModified: updatedAt,
    url: `https://curecordai.com/blog/${slug}`,
    mainEntityOfPage: {
      '@type': 'WebPage',
      '@id': `https://curecordai.com/blog/${slug}`,
    },
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
```

### 9.5 BreadcrumbSchema - app/components/seo/BreadcrumbSchema.tsx

Add to all pages except the homepage.

```tsx
interface BreadcrumbItem {
  name: string
  url: string
}

export default function BreadcrumbSchema({ items }: { items: BreadcrumbItem[] }) {
  const schema = {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, index) => ({
      '@type': 'ListItem',
      position: index + 1,
      name: item.name,
      item: item.url,
    })),
  }

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  )
}
```

**Usage:**

```tsx
<BreadcrumbSchema
  items={[
    { name: 'Home', url: 'https://curecordai.com' },
    { name: 'Blog', url: 'https://curecordai.com/blog' },
    { name: 'Post Title', url: 'https://curecordai.com/blog/post-slug' },
  ]}
/>
```

---

## 10. URL and Routing Rules

```
All URLs must be lowercase.
Use hyphens between words, never underscores.
No trailing slashes.
No query parameters in SEO-relevant URLs.
Keep URLs short and descriptive.
```

```
Correct:   /how-to-organize-medical-records
Wrong:     /HowToOrganizeMedicalRecords
Wrong:     /how_to_organize_medical_records
Wrong:     /blog?id=1
Wrong:     /blog/post/
```

For the blog, use a `[slug]` dynamic route in Next.js App Router. The slug must be the post title converted to lowercase with hyphens.

---

## 11. Performance Rules - Non-Negotiable

### Font Loading

```tsx
// Correct - in layout.tsx only
import { Inter } from 'next/font/google'
const inter = Inter({ subsets: ['latin'], display: 'swap' })

// Wrong - never do this in any component
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter" />
```

### Script Loading

```tsx
// For any third party scripts (analytics, etc.) use Next.js Script component
import Script from 'next/script'

// Load analytics after page is interactive - never block rendering
<Script src="..." strategy="afterInteractive" />

// For non-critical scripts load lazily
<Script src="..." strategy="lazyOnload" />

// Never load third party scripts in the <head> directly
```

### Lazy Loading

```tsx
// Lazy load components that are not visible on first screen load
import dynamic from 'next/dynamic'

const HeavyComponent = dynamic(() => import('@/components/HeavyComponent'), {
  loading: () => <p>Loading...</p>,
})
```

### Core Web Vitals Targets

```
LCP (Largest Contentful Paint):  Under 2.5 seconds on mobile
CLS (Cumulative Layout Shift):   Under 0.1
INP (Interaction to Next Paint): Under 200 milliseconds
```

The coding agent must test each page at `pagespeed.web.dev` before marking it complete. If mobile score is below 90, optimize before proceeding.

---

## 12. Canonical Tags - Rules

Every page sets its own canonical in its metadata export. Never rely on the root layout canonical for inner pages.

```tsx
// app/features/page.tsx
export const metadata: Metadata = {
  alternates: {
    canonical: 'https://curecordai.com/features',
  },
}
```

For the blog, the canonical must use the exact slug URL with no trailing slash.

```tsx
// app/blog/[slug]/page.tsx
export async function generateMetadata({ params }: { params: { slug: string } }) {
  return {
    alternates: {
      canonical: `https://curecordai.com/blog/${params.slug}`,
    },
  }
}
```

---

## 13. Authenticated App Zone - Block Completely

All pages inside the signed-in app (dashboard, health vault, profile, settings) must be completely blocked from search engine indexing using two layers.

**Layer 1 - robots.ts disallow list (already defined in Section 8)**

**Layer 2 - noindex meta on every authenticated layout:**

```tsx
// app/dashboard/layout.tsx
export const metadata: Metadata = {
  robots: {
    index: false,
    follow: false,
    noarchive: true,
    nosnippet: true,
  },
}
```

**Why both layers:** `robots.ts` tells crawlers not to visit the page. The `noindex` meta tag tells crawlers that if they somehow do visit it, do not index it. Health data must never appear in search results.

---

## 14. Open Graph Images

Create a default OG image at `public/og-default.jpg` sized exactly 1200x630 pixels. This image appears when any CurecordAI page is shared on WhatsApp, LinkedIn, or Twitter.

For blog posts, generate a dynamic OG image using Next.js `ImageResponse`:

```tsx
// app/blog/[slug]/opengraph-image.tsx
import { ImageResponse } from 'next/og'

export const runtime = 'edge'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/jpg'

export default async function BlogOGImage({
  params,
}: {
  params: { slug: string }
}) {
  return new ImageResponse(
    (
      <div
        style={{
          background: 'white',
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          padding: '60px',
          justifyContent: 'center',
        }}
      >
        <div style={{ fontSize: 60, fontWeight: 'bold', color: '#000' }}>
          {/* post.title */}
        </div>
        <div style={{ fontSize: 30, color: '#595959', marginTop: 20 }}>
          CurecordAI
        </div>
      </div>
    ),
    { ...size }
  )
}
```

---

## 15. Custom 404 Page - app/not-found.tsx

```tsx
import Link from 'next/link'
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Page Not Found',
  robots: { index: false, follow: true },
}

export default function NotFound() {
  return (
    <main>
      <h1>Page Not Found</h1>
      <p>The page you are looking for does not exist.</p>
      <Link href="/">Go back to homepage</Link>
    </main>
  )
}
```

---

## 16. Internal Linking Rules

```
Homepage must link to: Features, How It Works, Pricing, FAQ, Blog
Every blog post must link to: At least 2 other relevant blog posts and one product page
FAQ page must link to: Features page, How It Works page, Pricing page
Footer must link to: All main pages including Privacy Policy and Contact
```

Always use Next.js `<Link>` component, never a plain `<a>` tag for internal navigation:

```tsx
import Link from 'next/link'

// Correct
<Link href="/features">See all features</Link>

// Wrong for internal links
<a href="/features">See all features</a>
```

---

## 17. Blog Post Page Template - app/blog/[slug]/page.tsx

```tsx
import type { Metadata } from 'next'
import ArticleSchema from '@/components/seo/ArticleSchema'
import BreadcrumbSchema from '@/components/seo/BreadcrumbSchema'

async function getPost(slug: string) {
  // Return post data from your CMS or markdown files
}

export async function generateMetadata({
  params,
}: {
  params: { slug: string }
}): Promise<Metadata> {
  const post = await getPost(params.slug)

  return {
    title: post.title,
    description: post.excerpt,
    alternates: {
      canonical: `https://curecordai.com/blog/${params.slug}`,
    },
    openGraph: {
      title: post.title,
      description: post.excerpt,
      url: `https://curecordai.com/blog/${params.slug}`,
      type: 'article',
      publishedTime: post.publishedAt,
      modifiedTime: post.updatedAt,
      authors: [post.authorName],
    },
  }
}

export default async function BlogPost({
  params,
}: {
  params: { slug: string }
}) {
  const post = await getPost(params.slug)

  return (
    <>
      <ArticleSchema
        title={post.title}
        description={post.excerpt}
        publishedAt={post.publishedAt}
        updatedAt={post.updatedAt}
        slug={params.slug}
        authorName={post.authorName}
      />
      <BreadcrumbSchema
        items={[
          { name: 'Home', url: 'https://curecordai.com' },
          { name: 'Blog', url: 'https://curecordai.com/blog' },
          { name: post.title, url: `https://curecordai.com/blog/${params.slug}` },
        ]}
      />
      <main>
        <article>
          <h1>{post.title}</h1>
          <time dateTime={post.publishedAt}>{post.formattedDate}</time>
          <div>{/* Post content rendered here */}</div>
        </article>
      </main>
    </>
  )
}
```

---

## 18. Verification Files

After setup, the human team will provide verification codes for Google and Bing. Leave a comment placeholder:

```tsx
// In app/layout.tsx metadata export, add:
// TODO: Add Google Search Console verification code here
// verification: { google: '' },
```

---

## 19. Pre-Launch Validation Checklist for Coding Agent

```
[ ] Every public page has a unique title tag under 60 characters
[ ] Every public page has a unique meta description under 160 characters
[ ] Every public page has a canonical tag pointing to its own absolute URL
[ ] Every public page has Open Graph title, description, url, and image set
[ ] sitemap.xml is accessible at curecordai.com/sitemap.xml
[ ] robots.txt is accessible at curecordai.com/robots.txt
[ ] robots.txt disallows all authenticated app routes
[ ] All authenticated pages have noindex robots meta tag
[ ] OrganizationSchema is present on all pages (via root layout)
[ ] SoftwareAppSchema is on homepage
[ ] FAQSchema is on FAQ page
[ ] ArticleSchema and BreadcrumbSchema are on every blog post
[ ] BreadcrumbSchema is on all non-homepage pages
[ ] All images use Next.js Image component with descriptive alt text
[ ] All hero images have priority={true}
[ ] No render-blocking scripts or fonts
[ ] Google PageSpeed Insights mobile score is 90 or above on all pages
[ ] Custom 404 page exists and returns correct 404 status
[ ] All internal links use Next.js Link component
[ ] Footer links to all main pages including Privacy Policy
[ ] No console errors related to metadata or schema in browser dev tools
[ ] JSON-LD schema validated at search.google.com/test/rich-results
```

---

## 20. What the Coding Agent Must NOT Do

```
Do NOT use plain <img> tags - always use Next.js Image component
Do NOT use <a> tags for internal navigation - always use Next.js Link
Do NOT load Google Fonts via <link> tags - use next/font/google
Do NOT add noindex to public marketing pages
Do NOT expose authenticated routes to crawlers
Do NOT use the same title or description on more than one page
Do NOT use inline styles for layout - use Tailwind CSS classes
Do NOT add third party scripts in the <head> directly - use Next.js Script
Do NOT create URLs with uppercase letters, underscores, or query strings
Do NOT skip the canonical tag on any page
Do NOT use heading tags for styling purposes only
Do NOT leave alt attributes empty on informational images
```

---
