# Next.js Caching & Rendering Audit - `web/`

Scope: `web/` only (Next.js 14.2 App Router). Audit only - no code changed. All findings below were verified by reading the actual source files (all `app/` pages/layouts, all `app/api/` route handlers, all `lib/api/*`, `middleware.ts`, `next.config.mjs`, `app/globals.css`, and the marketing/dashboard/auth components involved in data fetching, images, and navigation).

## TL;DR

The app has two very different halves, and they have opposite problems:

- **Marketing site (`app/(marketing)/*`, `app/auth/*`, `app/coming-soon`)**: already close to ideal. Everything is a static Server Component with no dynamic APIs, `next/font` is used correctly, `<Link>`/prefetch is untouched and correct. Nothing here is "wasting" server work on every request - Next already statically renders these at build.
- **Dashboard app (`app/dashboard/*`)**: architecturally 100% client-rendered - every page is `"use client"` and fetches its own data post-mount via a shared hook (`useAsyncResource`) that has **no caching, no de-duplication, and no stale-while-revalidate**. This is the actual source of user-visible loading delays: every navigation back to a page the user already visited re-shows a blank "Loading…" text state and re-fetches from scratch, and some data (the user's own profile) is independently fetched up to three times per dashboard visit. This is the single biggest opportunity in the app.

Next.js's own fetch-cache/`revalidate` machinery (the thing sections 1–2 of the brief are usually about) barely applies here: only Route Handlers under `app/api/auth/*` run server-side, and all nine are POST mutation/token endpoints that are correctly never cached. Every data-bearing page in the app is a Client Component, so `fetch`'s `cache`/`next.revalidate` options - which only patch server-side fetches - are inert everywhere they appear. The real caching layer that's missing is a **client-side data cache** (SWR/React Query, or a hand-rolled equivalent), not `revalidate` tuning.

---

## 1. Page rendering strategy

No page or layout in the app exports `dynamic`, `revalidate`, or `fetchCache`, and none call `cookies()` or `headers()`. There is **no server-side-forced dynamic rendering anywhere** - the usual "page could be static but is forced dynamic" bug doesn't exist in this codebase.

| Route | Mode | Correct for UX? |
|---|---|---|
| `(marketing)/*` (9 pages incl. `blog/[slug]` via `generateStaticParams`) | Static Server Component | ✅ Correct - nothing here needs per-request data. |
| `auth/{signin,signup,forgot-password}` | Static Server Component shell + `"use client"` form | ✅ Correct - shell has no reason to be dynamic; only the form needs the client boundary. |
| `coming-soon` | Static | ✅ Correct. |
| `dashboard/emergency` | Static Server Component (no fetch, no `"use client"`) | ✅ Correct - the one dashboard page with no data dependency, and it's the only one not paying the client-component tax. |
| `dashboard/*` (all other 9 pages + layout) | `"use client"`, data fetched post-mount | ⚠️ Not a rendering-mode bug (auth is client-only, so there's no server session to render against), but see §7 - this is where the real UX cost lives. |

**Why dashboard pages can't just be flipped to Server Components today:** `AuthContext` (`lib/auth/AuthContext.tsx`) keeps the access token in an in-memory `useRef`, hydrated client-side via `POST /api/auth/refresh` reading an httpOnly cookie. No page or layout ever calls `cookies()` server-side to read that token. This is a legitimate architectural choice (keeps the access token out of anything server-rendered/loggable), but it's also *why* every dashboard page is forced client-only - there's no server-readable session to render the initial HTML against. Making any dashboard page a Server Component would require reading the refresh cookie server-side, which is a bigger auth-architecture decision than a caching audit should make unilaterally.

**Middleware**: `middleware.ts` matches `/((?!_next/).*)` - literally every request except static assets - but is a no-op unless `APP_LOCKED=true`. It doesn't read auth cookies and doesn't affect static/dynamic classification of any route. Low priority, but it does mean every request pays a middleware invocation for a flag that's presumably off in normal operation.

**Gaps not covered by "is it dynamic":**
- **Zero `loading.tsx` or `error.tsx` files exist anywhere in `app/`.** Confirmed via glob - no matches. This means Next's built-in route-level Suspense streaming/skeleton convention is entirely unused; every loading state is hand-rolled client text (see §3).
- Only one `<Suspense>` boundary exists in the whole app (`dashboard/assistant/page.tsx`), and it's only there because `useSearchParams()` requires one - its fallback is `null` (a blank flash), not a loading UI.

---

## 2. Data fetching and waterfalls

**All data fetching in this app happens client-side.** Every consumer of `lib/api/*` (14 files) is a `"use client"` component - no Server Component anywhere calls `apiFetch` or any `lib/api/*` function. This matters a lot for the audit: Next.js's `fetch` cache-extension options (`cache: 'force-cache'`, `next: { revalidate }`) only patch fetches made during server rendering. None of the fetch calls in `lib/api/client.ts` or elsewhere set these options, but adding them **would not do anything** as things stand today - there's no server-side fetch to patch. The actual gap is a client-side cache, not a Next.js `revalidate` config.

**Request waterfalls found (client-side, sequential `await` chains):**

1. **`app/dashboard/vault/page.tsx:32-37`** (`loadVaultRecords`) - `await listFamilyMembers(token)` then `await fetchAcrossFamily(familyMembers, ...)`. The per-member records genuinely need member IDs first, but the *owner's own* records don't depend on the family list at all and could be kicked off in parallel with it.
2. **`app/dashboard/share/page.tsx:23-26`** (`loadAllShareSessions`) - same `listFamilyMembers` → `fetchAcrossFamily` shape. Worse: this page separately calls `useAsyncResource(listFamilyMembers)` *and* `useAsyncResource(loadAllShareSessions)` (which internally re-fetches `listFamilyMembers`) - **the family member list is fetched twice on every load of this one page.**
3. **`app/dashboard/insights/page.tsx:29-37`** (`loadInsights`) - partially optimized (`Promise.all([listFamilyMembers, ...trends])` already), but the subsequent `fetchAcrossFamily(listRecords)` still waits on that batch to finish before starting - same one-hop dependency as #1.

**Already correctly parallelized (no action needed):**
- `dashboard/page.tsx` `loadDashboard` - 5 calls via one `Promise.all`.
- `dashboard/profile/page.tsx` `loadProfilePage` - `Promise.all([getProfile, getAppSettings])`.
- `components/dashboard/ProfileSwitcher.tsx` `loadSwitcherData` - `Promise.all([getProfile, listFamilyMembers])`.
- `familyAggregate.ts`'s `fetchAcrossFamily` itself already fans out with `Promise.all`.

**Redundant fetches (not technically a waterfall, but a direct UX cost - extra network round trips the user waits through):** `getProfile(token)` is independently fetched by up to **three** separate places on a normal dashboard visit - `dashboard/page.tsx`, `components/dashboard/ProfileSwitcher.tsx`, and `lib/theme/useSyncThemeWithAccount.ts` (on sign-in and again on every theme toggle) - with no shared cache, so each one is its own round trip for identical data.

**API route handlers (`app/api/auth/*`, 9 files):** all POST, all auth/token mutation endpoints (login, register, OTP verify, refresh, logout, password reset, OAuth). None set `cache`/`next.revalidate` on their outbound `fetch` to the backend, and none should - Next.js Route Handlers on non-GET methods are already dynamic/no-store by default, and these all mutate or rotate credentials. No waterfall risk here; each does exactly one backend proxy call.

---

## 3. Loading states

The shared `lib/hooks/useAsyncResource.ts` hook is the root cause of nearly every loading state in the dashboard: `isLoading` starts `true`, the fetch fires in a `useEffect` on mount, and there is **no cache, no SWR, no request de-dupe** built into it. Every mount of every page starts from zero, every time - navigate away and back, and it's blank again.

| Page | Loading UI | Note |
|---|---|---|
| `dashboard/page.tsx` | Full-page text swap (`Loading your dashboard...`) | Replaces the whole page, `PageHeading` included |
| `dashboard/alerts/page.tsx` | Inline text, page chrome stays mounted | Better pattern than the full-page-swap pages |
| `dashboard/assistant/page.tsx` | **No loading state at all** for the session list - renders empty until data arrives; `<Suspense fallback={null}>` is a blank flash, not a spinner | |
| `dashboard/family/page.tsx` | Inline text, chrome stays mounted | |
| `dashboard/insights/page.tsx` | Full-page text swap | |
| `dashboard/profile/page.tsx` | Full-page text swap | |
| `dashboard/share/page.tsx` | Loading text only covers the sessions list half - the QR-generation half has no loading gate at all | |
| `dashboard/vault/page.tsx` | Inline text, chrome stays mounted | |
| `dashboard/vault/[id]/page.tsx` | Full-page text swap; also polls every 3s while processing, with no visual distinction from initial load | Polling itself is a deliberate, correct design (mirrors the Flutter app's pattern for the same processing-state problem) |

**Only one true skeleton exists anywhere in the app**: `components/dashboard/ProfileSwitcher.tsx` (`animate-pulse` placeholder box) - and it fetches its data via its own independent `useAsyncResource(loadSwitcherData)` call, redundant with the page body's fetch (see §2).

**Where caching/prefetching would eliminate these loading states entirely:** any client-side cache (SWR/React Query) with a `staleTime` would let a returning visit to `dashboard/vault`, `dashboard/family`, etc. render the last-known data **instantly** while silently revalidating in the background - turning "blank text for 300-800ms on every nav" into "instant content, occasionally refreshed." This is exactly the stale-while-revalidate pattern already used successfully in the Flutter app's HTTP cache layer. Right now the web app has no equivalent at all.

---

## 4. Navigation experience

This part is in good shape and needs no changes:

- **Zero `prefetch={false}`** anywhere - every `<Link>` uses Next's default viewport-based prefetch.
- **Zero internal `<a href>` navigation** - the one raw `<a>` found (`dashboard/vault/[id]/page.tsx`) correctly opens an external S3 download URL in a new tab (`target="_blank"`), not an app route.
- **All `router.push`/`router.replace` calls are legitimately tied to an async action** (post-auth redirect, post-delete redirect, post-form-submit redirect) rather than replacing a plain clickable link - not an anti-pattern.
- **The dashboard shell does not remount on navigation.** `app/dashboard/layout.tsx` wraps `AuthProvider` → `ActiveProfileProvider` → `DashboardShell` once, shared across all `dashboard/*` routes per normal App Router layout semantics; `AuthContext`'s auth-check effect has an empty dependency array, so the "Loading your health vault..." full-shell gate only fires once per session, not on every internal nav.

**Why the router cache "feels" like it's not helping despite all this being correct:** the Next.js Router Cache only makes the *page shell/RSC payload* instant - it has nothing to do with the client-fetched data inside `useAsyncResource`. Since every dashboard page's real content loads via a fresh client fetch on every mount with no cache, navigating to an already-visited page still shows a loading state for the data even though the route transition itself is instant. This is the same root cause as §3, just observed from the navigation angle - fixing the client-cache gap fixes both.

---

## 5. API routes and response headers

All 9 route handlers live under `app/api/auth/*`. Every one is POST-only and either issues, rotates, or clears an auth credential (login, register ×2, OTP verify, OAuth ×2, refresh, logout, password reset). None set an explicit `Cache-Control` header, and **none should** - non-GET Route Handlers are dynamic/no-store by Next.js default, and every one of these mutates state or handles a secret. There are no GET API routes in the app at all, so the "public vs. authenticated, cacheable vs. not" split the brief asks for doesn't surface any findings - there's nothing here that's incorrectly cached or incorrectly uncached.

---

## 6. Static assets

**`next.config.mjs` is the bare default (`{}`)** - no `images` block at all (no `remotePatterns`/`domains`, no `minimumCacheTTL`, no `formats`), no `headers()`, no `experimental` caching config.

**Plain `<img>` tags (2, both explicitly `eslint-disable`d for `no-img-element`):**
- `app/dashboard/profile/page.tsx` - user avatar
- `components/dashboard/ProfileSwitcher.tsx` - avatar in the nav dropdown

Both are dynamic avatar URLs from what's presumably the API/S3 host. This is very likely *why* they're plain `<img>` in the first place - `next/image` can't optimize a remote host that isn't allow-listed in `images.remotePatterns`, and that allow-list is currently empty. That's a `next.config.mjs` gap, not a component-code mistake.

**`next/image` usage - all correct in shape, one real inconsistency:**
- Fonts are 100% correct: `app/layout.tsx` uses `next/font/google` (`Inter`, `display: "swap"`); `app/globals.css` has zero `@font-face`/`@import` for fonts; no `<link>` font tags anywhere in the repo. Nothing to fix here.
- Homepage hero (`components/marketing/home/HeroFeaturesPhone.tsx`): the main hero graphic is split into a left half (`priority` ✅) and a right half of the *same image* (no `priority`) - both are visible on first paint, only one is marked as an LCP candidate. Two supporting hero widgets (`left-widget.png`, `right-widget.png`), also visible on initial load, also lack `priority`. Net: **3 above-the-fold images without `priority`** sitting next to one that has it correctly.
- `StickyFeatureShowcase.tsx`'s scroll-triggered images correctly omit `priority` (they're below the fold) - no issue there.

No `minimumCacheTTL` is configured, so Next's default (60s) applies to locally-served `/public` images; format negotiation defaults to WebP only (no AVIF).

---

## 7. Authenticated app zone

This is the same root cause as §2/§3, restated from the "is stable data being re-fetched needlessly" angle the brief asks for:

- **Nothing in the dashboard zone caches or reuses previously-fetched data.** `useAsyncResource` re-fetches from scratch on every mount of every page, with no `staleTime`/TTL concept at all. A user bouncing between Vault → Family → Vault re-fetches the vault list from zero the second time, even though nothing changed.
- **Data stable enough to show instantly while revalidating in the background:** profile info, family member list, records/vault list, insights summary, alerts - all of it. None of it needs to be strictly real-time; all of it would benefit from "show cached, refresh silently" exactly the way the Flutter app's `HiveCacheStore` + `forceCache`/`refreshForceCache` policies already do for the equivalent screens (see the Flutter cache work referenced in project memory - this web app currently has no analogue of that layer at all).
- **One page correctly needs to stay live, not cached:** `dashboard/vault/[id]` polls every 3s while a document is mid-processing - same reasoning as the Flutter app's `recordFullProvider`, which was deliberately left uncached for the identical reason. Any future client-cache layer should exclude this endpoint the same way.

---

## 8. Public marketing pages

All fully static, all already correct - this is the one section of the brief with no findings:

- Homepage, `about`, `contact`, `faq`, `features`, `how-it-works`, `pricing`, `privacy`, `blog`, and `blog/[slug]` (via `generateStaticParams`) are plain Server Components with static `metadata`, no dynamic API calls, no auth reads. None of them hit the server per-request - Next already statically generates all of them at build time under the current (empty) config.
- `coming-soon` is also fully static.
- The only per-request work on this whole surface is the interactive bits that are already correctly isolated into small `"use client"` islands (`Navbar`, `ContactForm`) inside otherwise-static pages - the static/dynamic boundary is already drawn in the right place.

---

## Prioritized findings for Phase 2 (not yet implemented - awaiting approval)

1. **Add a client-side data cache** (SWR or React Query) as the fetching layer under `lib/api/*`/`useAsyncResource`, with a sensible `staleTime` for the endpoints listed in §7, excluding the `vault/[id]` polling endpoint. This is the highest-impact single change - it fixes §3's loading states and §4's "feels slow on revisit" in one move, and eliminates the redundant `getProfile`/`listFamilyMembers` fetches from §2.
2. **Fix the two `listFamilyMembers`→dependent-fetch waterfalls** (`vault`, `share`, `insights` pages) by kicking off the caller's-own-data fetch in parallel instead of waiting on the family list first.
3. **Configure `images.remotePatterns`** in `next.config.mjs` for the avatar/S3 host so the two `<img>` tags can become `next/image`.
4. **Add `priority` to the 3 above-the-fold hero images** in `HeroFeaturesPhone.tsx` that currently lack it.
5. **Add `loading.tsx` at the `app/dashboard/` segment** (or per-route) as a Suspense-driven skeleton fallback, replacing the hand-rolled full-page text swaps on `dashboard`, `insights`, `profile`, and `vault/[id]`.
6. Low priority: add an `app/error.tsx` / `app/dashboard/error.tsx` boundary (currently none exists anywhere); consider scoping `middleware.ts`'s matcher tighter if `APP_LOCKED` invocation overhead ever matters.

No code has been changed as part of this audit. Waiting for approval before Phase 2.
