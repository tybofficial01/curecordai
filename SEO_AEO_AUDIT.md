# CurecordAI Website - SEO & AEO Technical Audit

**Repo:** `curecordai/web` · **Framework:** Next.js 14.2.35 (App Router) · **Audited:** 2026-08-14
**Scope:** Marketing site, auth, doctor-share links, dashboard indexing boundary
**Method:** Static code review only. No application code was changed as part of this audit.

A code-level review of how the site appears to search engines, AI answer engines, and users. Every finding is tied to an actual file in the repository.

---

## Scores

| Category | Score |
|---|---|
| **Overall** | **78 / 100** |
| Technical SEO | 72 / 100 |
| On-Page SEO | 88 / 100 |
| AEO | 65 / 100 |
| Structured Data | 90 / 100 |
| Content | 80 / 100 |
| Internal Linking | 78 / 100 |
| Performance | 68 / 100 |
| Accessibility | 82 / 100 |

---

## Executive Summary

This is not a green-field audit. The repo contains its own internal spec, `CURECORDAI_WEBSITE_SEO_INSTRUCTIONS.md`, and the codebase follows it closely: every marketing page exports unique metadata, canonical URLs are absolute and page-specific, `robots.ts` and `sitemap.ts` exist and work, five JSON-LD schema components are implemented and used correctly, every image goes through `next/image`, and every internal link goes through `next/link`. That discipline shows up in the scores above - On-Page SEO and Structured Data are both strong.

Two things pull the overall grade down from where the rest of the implementation would otherwise land it:

1. **A page containing real patient health data is publicly indexable.** `/share/[token]` renders a patient's name, allergies, medications, conditions, and lab results, and it has no `robots` disallow entry and no `noindex` meta anywhere in its route tree. This is the one finding in this report that should be treated as a blocker, not a backlog item - see [Critical Issues](#critical-issues).
2. **The FAQ accordion doesn't render its own answers.** Nine of the ten FAQ answers on `/faq` (and two of three on the homepage) never enter the DOM until a visitor clicks to expand them. The JSON-LD `FAQPage` schema still carries the full text, but the actual page content that AI answer engines and Google's core content evaluation read does not. See [High Priority](#high-priority) and [AEO Deep Dive](#aeo-deep-dive).

Beyond those two, the remaining findings are refinements: internal link equity is split between the homepage's in-page sections and near-duplicate standalone pages, blog posts have no in-body subheadings, auth utility pages are needlessly indexable, and the marketing pages carry a heavy animation/scroll-jacking stack (Framer Motion + GSAP + Lenis + Spline + Lottie) worth watching for INP. None of these are urgent; all are listed with exact file references below.

---

## What Was Audited

**Framework:** Next.js 14.2.35, App Router, TypeScript, Tailwind CSS, deployed to Vercel (per the project's own instructions doc).
**Rendering:** The marketing route group `app/(marketing)/` is server-rendered/statically generated (plain `page.tsx` exports, no `"use client"` at the route level, `generateStaticParams` on the blog). Client components are used selectively for interaction (accordion, nav, theme toggle, scroll animation) - a correct, deliberate pattern, not blanket CSR. The one fully client-rendered *route* is `/share/[token]`, which fetches patient data in a `useEffect` with no server-rendered fallback content.

### Route inventory

| Route group | Routes | Should rank in search? | Currently blocked? |
|---|---|---|---|
| Marketing | `/, /features, /how-it-works, /pricing, /faq, /about, /contact, /privacy, /blog, /blog/[slug]` | Yes | n/a - indexable (correct) |
| Auth | `/auth/signin, /auth/signup, /auth/forgot-password` | No real search value | Not blocked (see Medium #1) |
| Doctor share link | `/share/[token]` | Never | **Not blocked** (see Critical #1) |
| Authenticated app | `/dashboard/*` | Never | `robots.ts` disallow + layout noindex (correct, layered) |
| Utility | `/coming-soon, /not-found` | No | noindex meta (correct) |
| API | `/api/auth/*` | Never | `robots.ts` disallow (correct) |

There are no duplicate URL variations to worry about - no trailing-slash routes, no query-string pagination, no www/non-www split visible in the app layer (that's a DNS/host concern outside this repo). The `middleware.ts` pre-launch gate (`APP_LOCKED` env flag) correctly sends `X-Robots-Tag: noindex, nofollow` on every redirect/503 it issues, and explicitly keeps `/share/` reachable through the gate - consistent with doctors needing tokenless access, but which is exactly why that route needs its own indexing policy rather than inheriting the marketing allowlist's implicit "reachable = fine" status.

---

## What's Already Working

Called out explicitly, since a fair audit isn't only a list of problems.

- ✔ Every marketing page exports its own unique `title`, `description`, and absolute `alternates.canonical` - no shared/duplicate metadata found anywhere in `app/(marketing)/`.
- ✔ `app/sitemap.ts` pulls blog URLs dynamically from `content/blog.ts` instead of hardcoding them - it can't go stale as posts are added, unlike the static example in the project's own spec doc.
- ✔ `app/dashboard/layout.tsx` sets `noindex, nofollow, noarchive, nosnippet` once at the layout level, cascading to every dashboard subroute - a single source of truth instead of per-page repetition.
- ✔ Five JSON-LD components (`Organization`, `SoftwareApplication`, `FAQPage`, `Article`, `BreadcrumbList`) are implemented, valid, and placed on the right pages - not sprayed everywhere out of availability.
- ✔ No plain `<img>` tags anywhere in the codebase - every image goes through `next/image`, including responsive `sizes` attributes on the scroll-driven showcase images.
- ✔ Decorative images correctly use `alt=""` with `aria-hidden` (e.g. the floating widget PNGs in `HeroFeaturesPhone.tsx`); informational images have specific, non-keyword-stuffed alt text.
- ✔ Every internal link goes through `next/link`, including inside the shared `Button` component, which only falls back to a plain anchor for external (`http`) hrefs, with `rel="noopener noreferrer"`.
- ✔ Fonts load via `next/font/google` (Inter) only - no external `<link>` stylesheet, no render-blocking font request.
- ✔ Each blog post gets a real, dynamically generated Open Graph image via `next/og` (`opengraph-image.tsx`) instead of reusing one static default - better social preview than the spec doc even asked for.
- ✔ No fabricated `aggregateRating`/review markup on the `SoftwareApplication` schema. There are no real ratings yet, so none were invented - correct restraint, not a gap.
- ✔ FAQ answer content itself (`content/faqs.ts`) is specific and genuinely useful - e.g. it directly answers "how is this different from ChatGPT" rather than dodging the comparison. Strong raw material for AEO, let down only by how it's rendered (see High #2).
- ✔ `SmoothScrollProvider.tsx` checks `prefers-reduced-motion` and skips Lenis entirely when set - correct accessibility default for a scroll-heavy site.

---

## Critical Issues

### 1. Patient health data is publicly indexable via doctor-share links

**Priority: Critical - fix before next deploy**

`/share/[token]` renders a patient's name, blood group, allergies (including criticality), active conditions, current medications, lab observations, and recent encounters - fetched client-side from `getPublicShare(token)`. This route has no `layout.tsx` and no `metadata` export anywhere in its tree, so it inherits no `robots` directive and defaults to fully indexable. `app/robots.ts` disallows only `/dashboard`, `/api/`, `/admin`, `/_next/` - `/share/` is absent. `middleware.ts` additionally special-cases `/share/` to stay reachable even during the pre-launch app lock, with no accompanying `X-Robots-Tag`.

**Why it matters:** If any share link is ever discovered by a crawler - pasted into a public forum, indexed via a WhatsApp group elsewhere, referrer-leaked from another site, or simply brute-forced/enumerated - Google can index and cache a real patient's name alongside their allergies and medications. This directly contradicts the product's own stated privacy posture (`content/site.ts` / `app/(marketing)/privacy/page.tsx`: "never visible to anyone unless you explicitly generate a share link... you control what is shared and for how long") and this repo's own `CLAUDE.md` security rules around never weakening data-access boundaries.

**Files:**
- `app/share/[token]/page.tsx` - no metadata export
- `app/robots.ts:10` - disallow list missing `/share`
- `middleware.ts:24–26` - explicitly allowlists `/share/`

**Recommended fix:** Add `app/share/[token]/layout.tsx` exporting `metadata = { robots: { index: false, follow: false, noarchive: true, nosnippet: true } }` (the same two-layer pattern already used for `/dashboard`), **and** add `"/share"` to the `disallow` array in `app/robots.ts`. Both layers are needed for the same reason the project's own instructions doc gives for the dashboard: `robots.ts` stops routine crawling, the meta tag stops indexing if a link is followed anyway.

---

## High Priority

### 1. FAQ answers aren't in the DOM until a user clicks

**Priority: High - fix soon, low effort, meaningful AEO/content-depth improvement**

`FAQAccordion.tsx` initializes `openIndex` to `0` and renders the answer with `{isOpen && (<div>...<p>{faq.answer}</p></div>)}`. That's a conditional render, not a CSS visibility toggle - for every FAQ except the first, the answer paragraph is entirely absent from the rendered HTML/DOM until the accordion item is opened. This hits `/faq` (9 of 10 answers missing), the homepage FAQ section (2 of 3 answers missing), and is harmless on `/features` only because that page has exactly one FAQ, which stays open by default.

**Why it matters:** The `FAQSchema` JSON-LD still contains the full text, so Google's dedicated FAQ rich-result parser sees everything. But the page's actual visible content - what Google's core content evaluation reads, and what AI answer engines extract when they fetch rendered HTML rather than parsing `<script type="application/ld+json">` - is nine paragraphs short of what the page appears to promise. This is the single biggest gap between "how good this content is" and "how much of it is actually extractable," which is the core AEO risk for this site.

**File:** `components/marketing/FAQAccordion.tsx:34–38`

**Recommended fix:** Keep all answers mounted in the DOM at all times and toggle visibility with CSS (e.g. a height/opacity transition, or simply always rendering the `<p>` and hiding it with `hidden` only when JS hasn't run) instead of conditionally mounting the JSX. This is a rendering change only - the interaction and visual design stay identical.

### 2. Homepage sections and standalone pages compete for the same topics

**Priority: High - worth a deliberate decision, not urgent**

The primary nav (`marketingNavLinks` in `content/site.ts:16–22`) points "Features," "How It Works," "Pricing," and "FAQ" at homepage anchors (`/#features`, `/#how-it-works`, etc.), not at the dedicated `/features`, `/how-it-works`, `/pricing`, `/faq` pages that also exist and are also in the sitemap. The two surfaces genuinely overlap in content: the homepage's `#features` section heading in `app/(marketing)/page.tsx:60` ("Everything you need to manage your family's health") is verbatim identical to the `/features` page's H1 in `app/(marketing)/features/page.tsx:54`.

**Why it matters:** Every primary-nav click and most footer traffic reinforces the homepage section, not the standalone page built to rank for that topic's own keywords with its own metadata and FAQ schema. That standalone page still gets an internal link (the homepage does link out to `/features`, `/how-it-works`, `/pricing`, and the FAQ page links to all three), but it's a secondary, lower-prominence link rather than the site's main navigational path - which weakens the internal-link signal Google uses to judge which URL you consider canonical for that topic. This may be intentional (fast in-page scroll UX on the homepage) - if so, keep it, but it should be a decision, not a default.

**Files:** `content/site.ts:16–22` · `app/(marketing)/page.tsx:53–121` · `app/(marketing)/features/page.tsx:54`

**Recommended fix:** Point primary nav at the standalone pages (`/features`, `/how-it-works`, `/pricing`, `/faq`) and let the homepage sections serve as a shorter preview/summary with their own distinct heading copy, rather than a duplicate of the dedicated page's H1.

---

## Medium Priority

### 1. Auth utility pages are indexable with no search value

`/auth/signin`, `/auth/signup`, and `/auth/forgot-password` each export a unique `title`/`description`/`canonical` but no `robots` directive, so they default to indexable.

**Why it matters:** These are pure-utility forms with no unique search intent behind them - nobody searches "curecordai sign in page" hoping to learn something. Indexing them adds crawl/index bloat without upside, and is inconsistent with how carefully every other route's indexability was considered.

**Files:** `app/auth/signin/page.tsx` · `app/auth/signup/page.tsx` · `app/auth/forgot-password/page.tsx`

**Recommended fix:** Add `robots: { index: false, follow: true }` to each page's metadata export (`follow: true` so the signup CTA link equity still passes through).

### 2. Blog posts have no in-body subheadings

`content/blog.ts` stores each post's body as a flat `content: string[]` of paragraphs, rendered in `app/(marketing)/blog/[slug]/page.tsx:68–74` as plain `<p>` tags with zero `<h2>`/`<h3>` structure between them.

**Why it matters:** Each of the four posts genuinely covers 2–3 distinct sub-questions (e.g. "Understanding Your Lab Report" covers what a reference range means, why an out-of-range value isn't automatically alarming, and when to actually worry) - but without subheadings, neither a skimming reader nor an AI answer engine can jump to or cite the specific sub-answer. This is the one place the content strategy (genuinely good, specific writing) is undercut by structure, not substance.

**Files:** `content/blog.ts` · `app/(marketing)/blog/[slug]/page.tsx:68–74`

**Recommended fix:** Change the content model from a flat string array to `{ heading?: string; body: string }[]` blocks, and render each heading as an `h2` under the post's existing `h1`.

### 3. Every blog post shares one generic, uncredentialed author

All four posts in `content/blog.ts` set `authorName: "CurecordAI Team"`, which flows straight into the `Article` schema's `author.name` (`components/seo/ArticleSchema.tsx:25–28`). There's no bio, credential, or byline link anywhere.

**Why it matters:** This content sits adjacent to medical information (how to read a lab report, what a reference range means). It's written responsibly - every post that touches a health judgment call explicitly says "confirm with your doctor" - but a generic team byline is a weaker E-E-A-T signal than a named author or reviewer would be, which matters more for this content category than for a typical SaaS blog. Not urgent given the current volume (four posts); worth deciding on an authorship model before the blog scales up.

**Files:** `content/blog.ts` · `components/seo/ArticleSchema.tsx`

**Recommended fix:** If there's a real person or clinical reviewer behind these posts, credit them by name with a short bio; otherwise this is a content/business decision, not a code fix.

### 4. Social links may point to inactive accounts

`content/site.ts:55–58` lists Twitter and Instagram in `socialLinks` (rendered in the footer), but `OrganizationSchema.tsx:10` only includes LinkedIn in `sameAs`.

**Why it matters:** If the Twitter/Instagram accounts aren't live yet, the footer links are dead ends for users, and it's worth confirming whether they were intentionally left out of `sameAs` because they're not live, or simply not added yet.

**Files:** `content/site.ts:55–58` · `components/seo/OrganizationSchema.tsx:10`

**Recommended fix:** Confirm which accounts are live; remove dead footer links and/or add live ones to `sameAs` for entity consistency.

---

## Low Priority / Optional

### 1. Four simultaneous `priority` images in the hero

`HeroFeaturesPhone.tsx:79–133` marks four `<Image priority>` elements as high-priority at once: two separate `<Image>` instances both pointing at `/output_clean.png` (the split-phone halves), plus `left-widget.png` and `right-widget.png`.

**Why it matters:** `priority` is meant to mark the single true LCP candidate so the browser preloads it above everything else. Marking four images priority dilutes that signal and can compete for early bandwidth during the moment that most affects LCP.

**File:** `components/marketing/home/HeroFeaturesPhone.tsx:79–133`

**Recommended fix:** Keep `priority` only on whichever single image is the actual largest initial paint (likely the merged `ai_chat.png` or one phone half); lazy-load the rest.

### 2. Source screenshot assets are 1–1.4MB PNGs

Twelve files in `public/` (the light/dark pairs for `ai-assistant`, `ai-report-summary`, `emergency-widget`, `family-management`, `health-insights`, `qr-sharing`, `records-vault`, plus `output_clean.png`) are each roughly 1–1.4MB as committed.

**Why it matters:** `next/image`'s on-demand optimizer resizes and re-encodes these at request time, so the bytes actually shipped to a visitor are much smaller than the source file - this is not a user-facing LCP emergency. But it directly violates the project's own budget in `CURECORDAI_WEBSITE_SEO_INSTRUCTIONS.md` ("Maximum image file size: 200KB for hero images, 100KB for content images"), and it bloats the repo and the image-optimizer's cold-start work.

**Files:** `public/*.png` (12 files)

**Recommended fix:** Compress/convert source screenshots to WebP before committing, targeting the project's own stated budget.

### 3. Heavy animation stack across every marketing page

The marketing bundle ships Framer Motion, GSAP + ScrollTrigger (`ProblemSection.tsx`), Lenis smooth-scroll (`SmoothScrollProvider.tsx`, wrapping the entire marketing layout), Spline (3D, `HeroSplineBackground.tsx`), and Lottie - five animation dependencies at once. Scroll-jacked sections push the DOM tall: the hero track is `h-[420vh]` (`HeroFeaturesPhone.tsx:275`) and the problem section pins a full `100dvh` viewport (`ProblemSection.tsx:242`).

**Why it matters:** More JS to parse/execute before these sections are interactive, and long-lived scroll listeners across multiple libraries raise INP risk on lower-end mobile devices, which is where this product's stated audience is likely to be. `SmoothScrollProvider` already respects `prefers-reduced-motion` correctly - worth confirming the GSAP and Framer Motion paths do the same, since that check wasn't verified end-to-end in every animated component during this audit.

**Files:** `components/marketing/home/HeroFeaturesPhone.tsx` · `components/marketing/home/ProblemSection.tsx` · `components/providers/SmoothScrollProvider.tsx`

**Recommended fix:** No action required unless real-user INP data (CrUX/Vercel Analytics) shows a problem - flagged for awareness, not as a defect. If cutting weight is desired, Spline (3D) is the heaviest single dependency to reconsider first.

---

## AEO Deep Dive

### Entity clarity: consistent

"What is CurecordAI" is answered the same way everywhere it's asked: an AI-powered personal health record app for patients and families in Pakistan, upload prescriptions/lab reports/discharge summaries, AI explains them in Urdu or English, one-tap doctor sharing, free. That exact framing appears in `content/site.ts`'s `siteConfig.description`, `OrganizationSchema.tsx`, `SoftwareAppSchema.tsx`, the homepage hero copy, the About page, and the first FAQ answer. A question-answering system encountering any single page would extract the same entity description as one encountering another - that consistency is exactly what AEO needs and it's already there.

The one differentiator claim worth double-checking before it's leaned on further: "How is CurecordAI different from ChatGPT" (`content/faqs.ts`) says CurecordAI answers are "specific to your actual diagnoses, medications, and lab results" while ChatGPT gives only generic answers. That's a legitimate and specific differentiation (personalization via your own uploaded records) - good AEO material because it's a real comparison, not a vague superiority claim.

### Question-answer structure: strong content, weak delivery

The FAQ content itself is a genuine asset for AEO - ten questions, each phrased the way a real person would ask it ("Can I use CurecordAI on WhatsApp?", "Is my health data private and secure?"), each answered directly in 2–4 sentences with no hedging or marketing fluff. That's close to ideal shape for an AI engine to lift a direct answer. The accordion rendering bug in [High Priority](#high-priority) is what stops that from paying off - fixing it is the single highest-leverage AEO change available in this codebase.

Blog posts also answer real questions in their opening sentence ("A lab report usually lists three things for each test...") but bury 2–3 distinct sub-answers inside one wall of text per post, which is the subheading gap noted in [Medium Priority](#medium-priority).

### Answer extractability

Where content *is* rendered, it's already extraction-friendly: FAQ answers are factual and concise with no marketing language, the "How CurecordAI Works" page states the three steps (Upload, Ask, Share) as short, literal descriptions rather than vague benefit statements, and the Pricing page states the free model plainly with no artificial scarcity language. The two things actively working against extractability are structural, not tonal: the accordion DOM issue, and the lack of blog subheadings. There is no content on this site written in a way that would confuse an AI system that could actually read it.

### Not recommended

Per the audit brief, these are explicitly *not* recommended, because they wouldn't be genuine:

- Adding more FAQs to `content/faqs.ts` purely for keyword coverage - the existing ten already cover the real question space (what/how, platforms, WhatsApp, differentiation, family, sharing, upload types, language, privacy, price). A useful eleventh question would come from real user support tickets, not from padding.
- Adding `AggregateRating`/`Review` schema to `SoftwareAppSchema.tsx` without real ratings to back it - already correctly avoided.
- Adding Medical/MedicalWebPage schema types - CurecordAI is a records/organization tool, not a source of medical guidance, and its own content is careful to say so ("does not replace a medical diagnosis"). Applying clinical schema types here would misrepresent what the product does.

---

## Content & Topical Gap Analysis

Based only on the site's actual positioning (family health records, Urdu/English AI explanations, Pakistan, WhatsApp access, free) - not generic "SEO content ideas."

### Must-have

- **A "sharing records with a specialist / hospital" angle already exists as a blog post** - good. The natural next must-have is the inverse: a short page or post addressed to *doctors* receiving a `/share/[token]` link for the first time, since that's a real, recurring audience this product creates (a doctor who's never seen CurecordAI before, opening a link mid-appointment). This should exist only once the Critical indexability issue is fixed, since it's the same audience touching the same route.
- **Urdu-language content parity.** The product's core differentiator is explaining records in Urdu, but every page audited (marketing copy, blog, FAQ) is English-only. This is a positioning gap, not a technical one: the product promises Urdu explanations but the marketing site never demonstrates that in Urdu itself.

### Nice-to-have

- A short comparison post/section addressing "CurecordAI vs. a WhatsApp folder of photos" - the exact scenario `ProblemSection.tsx` and the first blog post already describe qualitatively; turning that into a standalone answerable page would reinforce an angle the product already owns.
- An emergency-specific explainer page, since `/share/[token]` supports an `emergency_only` scope and the dashboard has a dedicated `/dashboard/emergency` route - the marketing site never explains this use case on its own, only as one line inside the blog post about aging parents.

Not recommended: generic "10 tips for staying healthy" style content unrelated to record-keeping/sharing. It wouldn't compete meaningfully and would dilute the site's otherwise tight topical focus.

---

## Page-by-Page Report

| Page | Indexable | Title | Meta desc. | H1 | Canonical | Schema | AEO | Main issue |
|---|---|---|---|---|---|---|---|---|
| `/` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | SoftwareApp, Org, FAQ(3) | Good | Duplicates `/features` H2 text |
| `/features` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | SoftwareApp, Breadcrumb, FAQ(1) | Good | Only reached via secondary link, not primary nav |
| `/how-it-works` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | Breadcrumb | Good | Same nav-priority note as above |
| `/pricing` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | Breadcrumb | Good | None significant |
| `/faq` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | FAQ(10), Breadcrumb | **Weak** | 9/10 answers not in DOM (High #1) |
| `/about` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | Breadcrumb | Fair | None significant |
| `/contact` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | Breadcrumb | N/A | None significant |
| `/privacy` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | Breadcrumb | Fair | "Last updated" is hardcoded copy |
| `/blog` | Yes | ✔ unique | ✔ unique | ✔ one | ✔ | Breadcrumb | Good | Only 4 posts currently |
| `/blog/[slug]` ×4 | Yes | ✔ unique/post | ✔ unique/post | ✔ one | ✔ | Article, Breadcrumb | **Fair** | No in-body H2/H3 (Medium) |
| `/auth/signin` | Should be No | ✔ unique | ✔ unique | - | ✔ | None | N/A | No noindex on a utility page (Medium) |
| `/auth/signup` | Should be No | ✔ unique | ✔ unique | - | ✔ | None | N/A | No noindex on a utility page (Medium) |
| `/auth/forgot-password` | Should be No | ✔ unique | ✔ unique | - | ✔ | None | N/A | No noindex on a utility page (Medium) |
| `/coming-soon` | No (correct) | ✔ | - | ✔ one | - | None | N/A | None - intentional |
| not-found | No (correct) | ✔ | - | ✔ one | - | None | N/A | None - intentional |
| `/dashboard/*` | No (correct) | n/a | n/a | n/a | n/a | None | N/A | None - layered noindex works |
| `/share/[token]` | **Yes - should be No** | - none | - none | ✔ one | - none | None | N/A | **Patient PHI indexable (Critical)** |

---

## File-by-File Report

| File | Change needed | Priority |
|---|---|---|
| `app/share/[token]/page.tsx` | Add a sibling `layout.tsx` exporting `robots: index:false, follow:false` | Critical |
| `app/robots.ts` | Add `"/share"` to the `disallow` array | Critical |
| `components/marketing/FAQAccordion.tsx` | Keep answer text mounted in the DOM at all times; toggle visibility with CSS, not conditional JSX | High |
| `content/site.ts` | Decide: point `marketingNavLinks` at standalone pages, or keep anchors as a deliberate choice | High |
| `app/(marketing)/page.tsx` | If nav is repointed, differentiate homepage section headings from the standalone pages' H1s | High |
| `app/auth/signin/page.tsx`, `signup/page.tsx`, `forgot-password/page.tsx` | Add `robots: index:false, follow:true` | Medium |
| `content/blog.ts` | Move from flat paragraph array to heading/body blocks | Medium |
| `app/(marketing)/blog/[slug]/page.tsx` | Render post subheadings as `h2` | Medium |
| `content/site.ts` | Verify/clean up Twitter & Instagram links vs. `OrganizationSchema` `sameAs` | Medium |
| `components/marketing/home/HeroFeaturesPhone.tsx` | Reduce simultaneous `priority` images to the single true LCP element | Low |
| `public/*.png` (12 files) | Recompress/convert source screenshots to WebP under the project's own size budget | Low |

---

## Recommended Implementation Plan

### Phase 1 - Critical technical fix (ship first)
- Add `app/share/[token]/layout.tsx` with `noindex, nofollow, noarchive, nosnippet`
- Add `/share` to `app/robots.ts` disallow list

### Phase 2 - Metadata & structured data
- Add `noindex` to the three `/auth/*` utility pages
- Reconcile `socialLinks` vs. `OrganizationSchema.sameAs`

### Phase 3 - AEO improvements
- Fix `FAQAccordion` so all answers are DOM-present (the single highest-leverage AEO change here)
- Add H2 subheadings to blog post bodies
- Decide and implement an authorship model for blog posts

### Phase 4 - Internal linking & content
- Point primary nav at `/features`, `/how-it-works`, `/pricing`, `/faq`
- Differentiate homepage section copy from the standalone pages' headings
- Consider the Urdu-parity and doctor-facing content gaps noted above, on the team's own timeline

### Phase 5 - Performance
- Limit hero `priority` to one image
- Recompress source PNGs to the project's own stated budget
- Spot-check GSAP/Framer Motion paths respect `prefers-reduced-motion` the way Lenis already does

---

*No runtime Lighthouse/PageSpeed data was collected - performance notes above are code-pattern based, not measured scores. No code was modified during this audit.*
