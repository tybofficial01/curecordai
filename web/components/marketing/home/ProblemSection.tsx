"use client";

import { useEffect, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Container } from "@/components/ui/Container";
import { FileX, Question, ClockCounterClockwise, FolderOpen } from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";
import { useIsomorphicLayoutEffect } from "@/lib/hooks/useIsomorphicLayoutEffect";

gsap.registerPlugin(ScrollTrigger);

// Compact row height (px) each glass detail card starts at before it expands.
const COMPACT_HEIGHT = 56;

// Alternating tilt (deg) each compact chip falls in at, for variety.
const FALL_TILT = [-14, 11, -9] as const;

// Flat brand-color treatment for the compact chips (Stage 3–5) - deliberately
// NOT glassmorphic, so they read as physical file tabs rather than UI panels.
// Same color for all three (theme-reactive primary/foreground pair, not raw hex).
const BRAND_CHIP = "bg-primary text-primary-foreground";

type PainPoint = {
  id: string;
  icon: Icon;
};

// Copy for each pain point lives under "problem.points.*" in
// messages/{locale}.json - only the icon and stable id are declared here.
const painPoints: PainPoint[] = [
  { id: "records", icon: FileX },
  { id: "reports", icon: Question },
  { id: "history", icon: ClockCounterClockwise },
];

export function ProblemSection() {
  const t = useTranslations("problem");
  const sectionRef = useRef<HTMLElement>(null);
  const introRef = useRef<HTMLDivElement>(null);
  const folderRef = useRef<HTMLDivElement>(null);
  const floatRef = useRef<HTMLDivElement>(null);
  const glowRef = useRef<HTMLDivElement>(null);
  const emptyRef = useRef<HTMLDivElement>(null);
  const detailLayerRef = useRef<HTMLDivElement>(null);

  const cardOuterRefs = useRef<(HTMLDivElement | null)[]>([]);
  const dockRefs = useRef<(HTMLDivElement | null)[]>([]);
  const cardBoxRefs = useRef<(HTMLDivElement | null)[]>([]);
  const compactGlassRefs = useRef<(HTMLDivElement | null)[]>([]);
  const fullDetailRefs = useRef<(HTMLDivElement | null)[]>([]);

  // The site header is `sticky top-0`, so once scrolled past it, it
  // permanently overlays whatever sits at the very top of the viewport -
  // including this section while GSAP pins it there. Measuring its real
  // height (rather than guessing) lets the pinned stage reserve exactly
  // that much space at the top instead of rendering underneath it.
  const [headerHeight, setHeaderHeight] = useState(72);

  useEffect(() => {
    const header = document.querySelector("header");
    if (!header) return;
    const observer = new ResizeObserver(([entry]) => setHeaderHeight(entry.contentRect.height));
    observer.observe(header);
    return () => observer.disconnect();
  }, []);

  // useIsomorphicLayoutEffect, not useEffect: ScrollTrigger's `pin: true` reparents this
  // section into a spacer wrapper it inserts directly into the DOM, entirely outside React's
  // own tracking. `ctx.revert()` in the cleanup below undoes that (unpins, removes the spacer)
  // - but a plain `useEffect`'s cleanup runs *after* React has already committed its own DOM
  // removals for an unmounting subtree, i.e. after React tried (and failed) to remove a node
  // from the parent it originally rendered it under, which by then had been replaced by
  // ScrollTrigger's spacer. That race is exactly what surfaced as an uncaught "NotFoundError:
  // Failed to execute 'removeChild' ... is not a child of this node" crash whenever navigating
  // away from the homepage (e.g. clicking a footer link to /contact, /about, /blog) while this
  // section's pin was still active. A layout effect's cleanup runs synchronously *before* React
  // removes the DOM, so `ctx.revert()` restores the real structure in time.
  useIsomorphicLayoutEffect(() => {
    // Guards the fonts.ready callback below: `ctx.revert()` in the cleanup already unpins and
    // restores this section's real DOM before React removes it, but if that promise resolves
    // afterward and fires an unguarded `ScrollTrigger.refresh()`, it could still mutate this
    // same, already-unmounting subtree.
    let cancelled = false;

    // Where a compact chip should land once it "flies" to the left dock,
    // expressed as a pixel delta from its current position - computed from
    // live rects (not baked in), so re-running this after any resize (via
    // invalidateOnRefresh below) keeps it accurate. `getProperty` subtracts
    // out whatever x/y GSAP has already applied, isolating the chip's true
    // un-transformed base position so the delta is correct regardless of
    // where the chip is mid-sequence.
    function getFlyDelta(i: number) {
      const card = cardOuterRefs.current[i];
      const dock = dockRefs.current[i];
      if (!card || !dock) return { x: 0, y: 0 };
      const cardRect = card.getBoundingClientRect();
      const curX = gsap.getProperty(card, "x") as number;
      const curY = gsap.getProperty(card, "y") as number;
      const baseLeft = cardRect.left - curX;
      const baseTop = cardRect.top - curY;
      const dockRect = dock.getBoundingClientRect();
      return {
        x: dockRect.left + dockRect.width / 2 - (baseLeft + cardRect.width / 2),
        y: dockRect.top + dockRect.height / 2 - (baseTop + cardRect.height / 2),
      };
    }

    const ctx = gsap.context(() => {
      // Idle float lives on its own element, never touched by the scrubbed
      // timeline, so it can never fight over the `y` property with it.
      gsap.to(floatRef.current, {
        y: -6,
        duration: 2.8,
        ease: "sine.inOut",
        repeat: -1,
        yoyo: true,
      });

      // Pre-reveal: fades the heading in during the ordinary (non-pinned) scroll-in that
      // already happens for free as this section approaches the viewport - *before* this
      // section's own pin below ("start: top top") engages. Without this, the heading stays at
      // its initial opacity:0 for the entire approach, so the one viewport-height of scroll the
      // Hero section above needs to physically un-stick its own `position: sticky` showcase
      // (unavoidable with that technique - see HeroFeaturesPhone.tsx) reads as a blank gap: this
      // section's background is already scrolling into place underneath, just with nothing
      // visible drawn on it yet. `.to()` tweens use the element's *current* value as their
      // start, so once this finishes (opacity:1, y:0) the pinned timeline's own Stage 1 tween
      // below animates from that same resting state - effectively a no-op, not a conflicting
      // second animation, so nothing double-animates or jumps.
      gsap.to(introRef.current, {
        opacity: 1,
        y: 0,
        ease: "none",
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top bottom",
          end: "top top",
          scrub: true,
        },
      });

      const tl = gsap.timeline({
        scrollTrigger: {
          trigger: sectionRef.current,
          start: "top top",
          end: "+=650%",
          scrub: 1,
          pin: true,
          anticipatePin: 1,
          invalidateOnRefresh: true,
        },
      });

      // Stage 1 - heading and the empty, premium-looking folder both settle
      // in together; nothing else exists yet.
      tl.to(introRef.current, { opacity: 1, y: 0, duration: 0.6, ease: "power2.out" }).to(
        folderRef.current,
        { opacity: 1, scale: 1, duration: 0.8, ease: "power3.out" },
        "<0.1",
      );

      // Stage 3 - all three compact, flat-colored chips fall in together with
      // a gravity ease and bounce on landing, while the folder compresses +
      // glows once with the shared impact. Synchronized on a single "drop"
      // label so one scroll interaction lands the whole group at once,
      // instead of each chip landing on its own sequential turn.
      tl.to(emptyRef.current, { opacity: 0, duration: 0.3 }, "+=0.35");
      tl.addLabel("drop", "<");

      painPoints.forEach((_point, i) => {
        const card = cardOuterRefs.current[i];
        if (!card) return;

        tl.to(card, { opacity: 1, y: 0, rotation: 0, duration: 1, ease: "power2.in" }, "drop")
          .to(card, { y: -14, duration: 0.15, ease: "power1.out" }, "drop+=1")
          .to(card, { y: 0, duration: 0.3, ease: "elastic.out(1, 0.5)" }, "drop+=1.15");
      });

      tl.to(folderRef.current, { scaleY: 0.985, duration: 0.08, ease: "power1.out" }, "drop+=1.15")
        .to(folderRef.current, { scaleY: 1, duration: 0.28, ease: "elastic.out(1, 0.4)" }, "drop+=1.23")
        .to(glowRef.current, { opacity: 0.8, duration: 0.12 }, "drop+=0.95")
        .to(glowRef.current, { opacity: 0.3, duration: 0.5 }, "drop+=1.07");

      // Stage 4 pause happens for free: the next tween below starts a full
      // "+=0.5" after the last drop settles, holding the completed stack.

      // Stage 5 - the chips smoothly fly to the dock under the heading,
      // via transform only (no re-parenting): a computed pixel offset from
      // their current spot to the dock's live position.
      tl.addLabel("fly", "+=0.5");
      painPoints.forEach((_point, i) => {
        const card = cardOuterRefs.current[i];
        if (!card) return;
        tl.to(
          card,
          {
            x: () => getFlyDelta(i).x,
            y: () => getFlyDelta(i).y,
            scale: 0.92,
            duration: 1.2,
            ease: "power3.inOut",
          },
          i === 0 ? "fly" : `fly+=${i * 0.12}`,
        );
      });

      // Stage 6 - the folder's contents transform: the flat chip layer is
      // now vacated, and the glass detail layer fades in as small pills
      // that echo the chips' shape before each expands in turn.
      tl.to(detailLayerRef.current, { opacity: 1, duration: 0.6 }, "+=0.4");

      painPoints.forEach((_point, i) => {
        const box = cardBoxRefs.current[i];
        const compact = compactGlassRefs.current[i];
        const full = fullDetailRefs.current[i];
        if (!box || !compact || !full) return;

        const pos = i === 0 ? "+=0.25" : "+=0.4";
        tl.to(box, { height: () => full.scrollHeight, duration: 0.9, ease: "power2.inOut" }, pos)
          .to(compact, { opacity: 0, duration: 0.3 }, "<")
          .to(full, { opacity: 1, duration: 0.5 }, "<+0.15");
      });

      // Everything is collected and explained - a last soft glow reads as
      // "organized", then holds before releasing into the next section.
      tl.to(glowRef.current, { opacity: 0.5, duration: 0.6 }, "+=0.3")
        .to(glowRef.current, { opacity: 0.22, duration: 0.8 })
        .to({}, { duration: 0.3 });
    }, sectionRef);

    document.fonts?.ready?.then(() => {
      if (!cancelled) ScrollTrigger.refresh();
    });

    return () => {
      cancelled = true;
      ctx.revert();
    };
  }, []);

  return (
    <section
      ref={sectionRef}
      className="relative flex h-[100dvh] items-center bg-background pb-[clamp(1rem,4vh,4rem)] sm:pb-[clamp(1.5rem,5vh,5rem)]"
      style={{ paddingTop: `calc(${headerHeight}px + clamp(1rem, 3vh, 2rem))` }}
    >
      <Container className="relative z-10 w-full">
        <div className="grid items-center gap-6 sm:gap-8 md:grid-cols-2 md:gap-16">
          <div ref={introRef} className="mx-auto max-w-lg text-center md:mx-0 md:text-start" style={{ opacity: 0, transform: "translateY(16px)" }}>
            <h2 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl lg:text-5xl">
              {t("heading")}
            </h2>
            <p className="mt-4 text-base leading-relaxed text-ink-muted sm:text-lg">{t("body")}</p>

            {/* Dock for the compact chips once they arrive in Stage 5 - kept
                the same shape/size as the real chips (just invisible) so it
                reserves accurate, stable geometry to fly toward. */}
            <div className="mt-6 flex flex-wrap items-center justify-center gap-3 md:justify-start">
              {painPoints.map((point, i) => (
                <div
                  key={point.id}
                  ref={(el) => {
                    dockRefs.current[i] = el;
                  }}
                  className={`invisible inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-semibold ${BRAND_CHIP}`}
                >
                  <point.icon size={16} weight="bold" />
                  {t(`points.${point.id}.compact`)}
                </div>
              ))}
            </div>
          </div>

          <div className="relative flex items-center justify-center">
            <div
              ref={glowRef}
              aria-hidden
              className="pointer-events-none absolute inset-6 rounded-[36px] bg-highlight/25 blur-3xl"
              style={{ opacity: 0 }}
            />

            <div
              ref={folderRef}
              className="relative h-[clamp(320px,52vh,400px)] w-full max-w-sm rounded-[28px] border border-highlight/20 bg-white/5 shadow-[0_20px_60px_rgba(0,0,0,0.4)] backdrop-blur-xl sm:h-[clamp(360px,56vh,480px)] sm:max-w-md lg:h-[clamp(400px,60vh,560px)]"
              style={{ opacity: 0, transform: "scale(0.9)" }}
            >
              <div ref={floatRef} className="absolute inset-0">
                {/* Layer A - empty state + flat brand-color chip stack. Both
                    absolutely positioned and centered, so neither ever
                    reserves layout height on the folder itself: nothing can
                    look like an awkward empty gap because the folder's size
                    never depends on this layer's contents. */}
                <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 p-6">
                  <div
                    ref={emptyRef}
                    className="absolute flex flex-col items-center gap-2 text-center text-ink-faint"
                  >
                    <FolderOpen size={40} weight="duotone" />
                    <p className="text-sm">{t("empty")}</p>
                  </div>

                  {painPoints.map((point, i) => (
                    <div
                      key={point.id}
                      ref={(el) => {
                        cardOuterRefs.current[i] = el;
                      }}
                      className={`inline-flex items-center gap-2 rounded-full px-5 py-2.5 text-sm font-semibold shadow-lg ${BRAND_CHIP}`}
                      style={{ opacity: 0, transform: `translateY(-220px) rotate(${FALL_TILT[i]}deg)` }}
                    >
                      <point.icon size={16} weight="bold" />
                      {t(`points.${point.id}.compact`)}
                    </div>
                  ))}
                </div>
              </div>

              {/* Layer B - glassmorphic detail cards, revealed in Stage 6. Kept
                  as a sibling of floatRef (not inside it) so the idle bob
                  applied to floatRef never carries this layer's top edge past
                  the folder's static border. Each card starts compact-height
                  (echoing the chip it replaces) and grows smoothly into the
                  full explanation. */}
              <div
                ref={detailLayerRef}
                className="absolute inset-0 flex flex-col items-center justify-end gap-4 overflow-hidden rounded-[28px] p-6"
                style={{ opacity: 0 }}
              >
                {painPoints.map((point, i) => (
                  <div
                    key={point.id}
                    ref={(el) => {
                      cardBoxRefs.current[i] = el;
                    }}
                    className="w-full shrink-0 overflow-hidden rounded-2xl border border-highlight/20 bg-white/5 shadow-[0_8px_24px_rgba(0,0,0,0.3)] backdrop-blur-xl"
                    style={{ height: COMPACT_HEIGHT }}
                  >
                    <div className="relative">
                      <div
                        ref={(el) => {
                          compactGlassRefs.current[i] = el;
                        }}
                        className="absolute inset-x-0 top-0 flex items-center gap-2 px-5 py-4"
                      >
                        <point.icon size={18} className="text-highlight" weight="bold" />
                        <span className="text-sm font-semibold text-ink">{t(`points.${point.id}.compact`)}</span>
                      </div>
                      <div
                        ref={(el) => {
                          fullDetailRefs.current[i] = el;
                        }}
                        className="flex flex-col gap-2 px-5 py-4"
                        style={{ opacity: 0 }}
                      >
                        <point.icon size={22} className="text-highlight" weight="duotone" />
                        <h3 className="text-base font-semibold text-ink">{t(`points.${point.id}.title`)}</h3>
                        <p className="text-sm leading-relaxed text-ink-muted">{t(`points.${point.id}.description`)}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </Container>
    </section>
  );
}
