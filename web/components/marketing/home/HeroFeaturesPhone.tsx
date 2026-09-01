"use client";

import Image from "next/image";
import { useRef, useState } from "react";
import { motion, useScroll, useTransform, type MotionValue } from "framer-motion";
import { useTranslations } from "next-intl";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";
import { SparkleField } from "@/components/marketing/home/SparkleField";
import { useIsomorphicLayoutEffect } from "@/lib/hooks/useIsomorphicLayoutEffect";
import { useTheme } from "@/lib/useTheme";
import { Link } from "@/i18n/navigation";
import { ArrowRight, Sparkle } from "@phosphor-icons/react/dist/ssr";

const easeOut = [0.16, 1, 0.3, 1] as const;

// Phase boundaries for the pinned showcase below, all expressed as fractions
// of the track's scroll progress (0 = the moment it locks to the top of the
// viewport, 1 = the moment it releases back into normal scroll). Each phase
// gets its own non-overlapping window so nothing animates concurrently - the
// merge finishes and holds, then it zooms in once fully seen, then the
// heading, then the paragraph, each only starting once the previous one has
// settled. PARA_END lands at 1 so release happens the instant the paragraph
// finishes fading in, with no idle hold afterward. Note: the ~1 viewport of
// scroll needed for this `sticky` stage to physically un-stick after that is
// unavoidable with this technique - ProblemSection.tsx absorbs it by fading
// its own heading in during the ordinary (non-pinned) scroll-in that already
// happens for free while that un-stick is playing out, so the handoff never
// reads as a blank gap. See the "Pre-reveal" comment in that file.
const MERGE_START = 0.05;
const MERGE_END = 0.37;
const ZOOM_IN_START = 0.51;
const ZOOM_IN_END = 0.63;
const HEADING_START = 0.71;
const HEADING_END = 0.83;
const PARA_START = 0.88;
const PARA_END = 1;

/**
 * Two phones (mockup.png) that slide together and crossfade into a
 * single merged phone showing the AI chat screen. Runs once, early in the
 * pinned track (MERGE_START–MERGE_END), then holds fully at rest so it can
 * be seen in full before anything else happens. Once it's had that moment,
 * it zooms in slightly (ZOOM_IN_START–ZOOM_IN_END) for emphasis, staying
 * comfortably inside the stage's bounds so it's never clipped - after that
 * it never moves again. Sizing is height-driven (h-full of its parent,
 * whose height is animated by the caller) so it always fills whatever
 * space it's given, on any viewport.
 */
function HeroMergePhones({ progress }: { progress: MotionValue<number> }) {
  const { theme } = useTheme();
  const isLight = theme === "light";
  const t = useTranslations("home");

  // Phone centers in mockup.png as a fraction of its (square) width -
  // measured from the source asset so the slide distance lands the two
  // phones exactly on top of one another at full progress.
  const leftPhoneCenter = 0.3246;
  const rightPhoneCenter = 0.6839;

  const splitLeftX = useTransform(progress, [MERGE_START, MERGE_END], ["0%", `${(0.5 - leftPhoneCenter) * 100}%`]);
  const splitRightX = useTransform(progress, [MERGE_START, MERGE_END], ["0%", `${(0.5 - rightPhoneCenter) * 100}%`]);
  const splitScale = useTransform(progress, [MERGE_START, MERGE_END], [1, 0.92]);
  const splitOpacity = useTransform(progress, [MERGE_START, MERGE_END - 0.06, MERGE_END], [1, 1, 0]);

  const widgetOpacity = useTransform(progress, [MERGE_START, MERGE_START + 0.14], [1, 0]);
  const leftWidgetX = useTransform(progress, [MERGE_START, MERGE_START + 0.14], ["0%", "-8%"]);
  const leftWidgetY = useTransform(progress, [MERGE_START, MERGE_START + 0.14], ["0%", "5%"]);
  const rightWidgetX = useTransform(progress, [MERGE_START, MERGE_START + 0.14], ["0%", "8%"]);
  const rightWidgetY = useTransform(progress, [MERGE_START, MERGE_START + 0.14], ["0%", "5%"]);

  // Crossfades in as the split halves fade out, settling to its true scale
  // right as the merge window ends, holds there fully visible, then zooms
  // in slightly once it's had its showcase moment - never moving again
  // after that. The end scale is kept modest (not larger) so the phone
  // stays fully inside the stage's bounds rather than clipping against it.
  const mergedOpacity = useTransform(progress, [MERGE_END - 0.1, MERGE_END], [0, 1]);
  const mergedScale = useTransform(
    progress,
    [MERGE_END - 0.1, MERGE_END, ZOOM_IN_START, ZOOM_IN_END],
    [0.94, 1, 1, 1.14],
  );

  return (
    <div className="relative aspect-square h-full max-w-full">
      {/* Two phones, split down the middle so each half can travel toward
          the other independently. */}
      <motion.div style={{ opacity: splitOpacity }} className="absolute inset-0">
        <motion.div
          style={{ x: splitLeftX, scale: splitScale }}
          className="absolute inset-0 [clip-path:inset(0_50%_0_0)]"
        >
          <Image
            src={isLight ? "/mockup_light.png" : "/mockup.png"}
            alt={t("dashboardAlt")}
            fill
            priority
            sizes="(min-width: 1024px) 480px, 70vw"
            className="object-contain"
          />
        </motion.div>
        <motion.div
          style={{ x: splitRightX, scale: splitScale }}
          className="absolute inset-0 [clip-path:inset(0_0_0_50%)]"
        >
          <Image
            src={isLight ? "/mockup_light.png" : "/mockup.png"}
            alt={t("reportSummaryAlt")}
            fill
            priority
            sizes="(min-width: 1024px) 480px, 70vw"
            className="object-contain"
          />
        </motion.div>
      </motion.div>

      {/* Shortcut widget, anchored over the left phone's quick-action grid. */}
      <motion.div
        style={{ opacity: widgetOpacity, x: leftWidgetX, y: leftWidgetY }}
        className="absolute left-[6%] top-[34%] w-[26%] -rotate-6 drop-shadow-[0_16px_24px_rgba(0,0,0,0.35)]"
      >
        <Image
          src={isLight ? "/left-widget-light.png" : "/left-widget.png"}
          alt=""
          aria-hidden
          width={558}
          height={447}
          priority
          className="h-auto w-full"
        />
      </motion.div>

      {/* Trends widget, anchored over the right phone's chart. */}
      <motion.div
        style={{ opacity: widgetOpacity, x: rightWidgetX, y: rightWidgetY }}
        className="absolute right-[4%] top-[24%] w-[24%] rotate-6 drop-shadow-[0_16px_24px_rgba(0,0,0,0.35)]"
      >
        <Image
          src={isLight ? "/right-widget-light.png" : "/right-widget.png"}
          alt=""
          aria-hidden
          width={554}
          height={450}
          priority
          className="h-auto w-full"
        />
      </motion.div>

      {/* Merged phone: crossfades in as the two halves converge, revealing
          the AI chat screen, then holds still for the rest of the pin. */}
      <motion.div
        style={{ opacity: mergedOpacity, scale: mergedScale }}
        className="absolute inset-0 flex items-center justify-center"
      >
        <div className="animate-card-float relative h-full w-[42%]">
          <Image
            src={isLight ? "/aichat_light.png" : "/aichat_dark.png"}
            alt={t("aiChatAlt")}
            fill
            sizes="(min-width: 1024px) 280px, 40vw"
            className="object-contain"
          />
        </div>
      </motion.div>
    </div>
  );
}

export function HeroFeaturesPhone() {
  const t = useTranslations("home");
  const trackRef = useRef<HTMLDivElement>(null);
  const stackRef = useRef<HTMLDivElement>(null);
  const textRef = useRef<HTMLDivElement>(null);

  // Drives the whole pinned showcase. With offset ["start start", "end
  // end"] and a track taller than one viewport, this progress runs 0→1
  // across exactly the span during which the inner `sticky` stage stays
  // locked in place - it hits 1 right as the stage would naturally unstick,
  // so scroll release back into the next section falls out for free with
  // no extra logic.
  const { scrollYProgress: progress } = useScroll({
    target: trackRef,
    offset: ["start start", "end end"],
  });

  // Real, measured pixel sizes (not guessed breakpoint values) so the phone
  // stage always fills exactly what's available on the current device: the
  // full stack height while it merges/zooms, then just the space left over
  // once the heading and paragraph need room below it.
  const [stackHeight, setStackHeight] = useState(0);
  const [textHeight, setTextHeight] = useState(0);
  const [gapPx, setGapPx] = useState(24);

  // useIsomorphicLayoutEffect (not useEffect): this ResizeObserver drives phoneHeight below,
  // which the whole merge/zoom sequence is sized against. A plain useEffect starts observing
  // only after the browser has already painted the stackHeight=0 initial state, so the phone
  // stage (and every `fill` Image inside it, including the merged AI chat screen) briefly
  // renders at zero height before snapping to its real size on the next frame - same class of
  // paint-before-measure race ProblemSection works around for the same reason (see that
  // component's comment on this hook). Starting the observer during the layout-effect phase
  // means the first measurement lands before paint instead of after it.
  useIsomorphicLayoutEffect(() => {
    const stackEl = stackRef.current;
    const textEl = textRef.current;
    if (!stackEl || !textEl) return;

    const mediaQuery = window.matchMedia("(min-width: 640px)");
    const updateGap = () => setGapPx(mediaQuery.matches ? 32 : 24); // mirrors gap-6 / sm:gap-8 below
    updateGap();
    mediaQuery.addEventListener("change", updateGap);

    const stackObserver = new ResizeObserver(([entry]) => setStackHeight(entry.contentRect.height));
    const textObserver = new ResizeObserver(([entry]) => setTextHeight(entry.contentRect.height));
    stackObserver.observe(stackEl);
    textObserver.observe(textEl);

    return () => {
      mediaQuery.removeEventListener("change", updateGap);
      stackObserver.disconnect();
      textObserver.disconnect();
    };
  }, []);

  const settledHeight = Math.max(stackHeight - textHeight - gapPx, 0);
  // Full height while sliding/merging/zooming, so that whole sequence plays
  // dead-center in the viewport; eases down to the leftover space right as
  // the heading starts revealing, so the copy below never overlaps it.
  const phoneHeight = useTransform(progress, [ZOOM_IN_END, HEADING_START], [stackHeight, settledHeight]);

  const headingOpacity = useTransform(progress, [HEADING_START, HEADING_END], [0, 1]);
  const headingY = useTransform(progress, [HEADING_START, HEADING_END], [20, 0]);
  const paraOpacity = useTransform(progress, [PARA_START, PARA_END], [0, 1]);
  const paraY = useTransform(progress, [PARA_START, PARA_END], [20, 0]);

  return (
    <div className="relative">
      {/* -mt-20/pt-20 pulls this section's own background up behind the fixed-height
          sticky header (h-20) instead of leaving the header's reserved flow space to
          show the page's default --color-background — otherwise that gap reads as a
          mismatched band behind the transparent glass navbar. Content position is
          unchanged since the padding cancels the margin. */}
      <section className="bg-grain relative -mt-20 bg-[var(--hero-bg)] pt-20">
        <SparkleField />

        {/* Light ambient green glow at the top-left/top-right of the heading
            area, clipped to its own overflow-hidden layer scoped to the
            initial viewport so it doesn't widen the page or affect the
            sticky pin used by the scroll-driven showcase further down. */}
        <div aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-screen overflow-hidden">
          <div className="absolute -left-32 top-0 h-80 w-80 rounded-full bg-highlight/15 blur-[110px]" />
          <div className="absolute -right-32 top-0 h-80 w-80 rounded-full bg-highlight/15 blur-[110px]" />
        </div>

        {/* Intro copy: plain, non-pinned entrance animation, scrolls away
            normally once the pinned showcase below takes over. */}
        <Container className="relative z-10 flex flex-col items-center pb-10 pt-6 text-center sm:pt-8 lg:pt-10">
          <motion.span
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, ease: easeOut, delay: 0.1 }}
            className="inline-flex items-center gap-2 rounded-full border border-primary/30 bg-primary/10 px-4 py-1.5 text-sm font-medium text-highlight"
          >
            <Sparkle size={16} weight="fill" />
            {t("badge")}
          </motion.span>

          <motion.h1
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: easeOut, delay: 0.2 }}
            className="mt-4 max-w-3xl text-4xl font-semibold leading-[1.1] tracking-tight text-ink sm:text-5xl lg:text-6xl"
          >
            {t("heroTitle")}{" "}
            <span className="bg-gradient-to-r from-highlight to-primary bg-clip-text text-transparent">
              {t("heroTitleHighlight")}
            </span>
          </motion.h1>

          <motion.p
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: easeOut, delay: 0.3 }}
            className="mx-auto mt-4 max-w-xl text-lg leading-relaxed text-ink-muted"
          >
            {t("heroSubtitle")}
          </motion.p>

          <motion.div
            initial={{ opacity: 0, y: 24 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, ease: easeOut, delay: 0.4 }}
            className="mt-6 flex flex-col items-center justify-center gap-4 sm:flex-row"
          >
            <Button href="/auth/signup" className="gap-2">
              {t("ctaPrimary")} <ArrowRight size={18} />
            </Button>
            <Link
              href="/how-it-works"
              className="inline-flex items-center justify-center gap-2 rounded-full border border-border bg-transparent px-6 py-3 text-base font-semibold text-ink transition-colors hover:bg-ink/5"
            >
              {t("ctaSecondary")}
            </Link>
          </motion.div>
        </Container>

        {/* Pinned showcase: phones merge into the AI chat screen and hold
            there, fully visible and centered, while the headline and
            paragraph reveal in sequence - release happens right as the
            paragraph finishes (see PARA_END above), so scroll hands off to
            the next section as soon as this one's content is fully shown,
            with no idle hold in between. Track height sets how much scroll
            distance the whole sequence gets; the sticky stage inside is
            exactly one viewport tall. Shorter on narrow viewports so the
            same sequence doesn't drag across an oversized scroll distance
            on mobile. */}
        <div ref={trackRef} className="relative h-[160vh] sm:h-[220vh] lg:h-[344vh]">
          <div className="sticky top-0 h-screen overflow-hidden">
            <Container className="relative z-10 h-full py-10">
              <div ref={stackRef} className="relative h-full">
                {/* Phone stage: pinned to the top of the available height,
                    sized by scroll progress (see phoneHeight above) - full
                    height while merging, so it sits dead-center in the
                    viewport for a clear view, then settles down to make
                    room for the copy below. */}
                <motion.div
                  style={{ height: phoneHeight }}
                  className="absolute inset-x-0 top-0 flex items-center justify-center"
                >
                  <HeroMergePhones progress={progress} />
                </motion.div>

                {/* Heading + paragraph: pinned to the bottom of the available
                    height. The phone above never overlaps it because its
                    settled height always leaves exactly this block's
                    measured height (plus gap) free. */}
                <div className="absolute inset-x-0 bottom-0 pb-6 sm:pb-8">
                  <div ref={textRef} className="mx-auto max-w-xl text-center">
                    <motion.h2
                      style={{ opacity: headingOpacity, y: headingY }}
                      className="text-3xl font-semibold tracking-tight text-ink sm:text-4xl"
                    >
                      {t("pinnedHeading")}
                    </motion.h2>
                    <motion.p
                      style={{ opacity: paraOpacity, y: paraY }}
                      className="mt-3 text-lg leading-relaxed text-ink-muted"
                    >
                      {t("pinnedBody")}
                    </motion.p>
                  </div>
                </div>
              </div>
            </Container>
          </div>
        </div>

        {/* Fades the hero's pure black into ProblemSection's slightly lighter
            --color-background so the two sections blend instead of cutting
            at a hard, visible seam. */}
        <div
          aria-hidden
          className="pointer-events-none absolute inset-x-0 bottom-0 h-16 bg-gradient-to-b from-transparent to-background sm:h-24"
        />
      </section>
    </div>
  );
}
