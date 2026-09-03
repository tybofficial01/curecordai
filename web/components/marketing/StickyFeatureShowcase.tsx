"use client";

import { useRef, useState } from "react";
import { useTranslations } from "next-intl";
import Image from "next/image";
import { AnimatePresence, motion, useMotionValueEvent, useScroll } from "framer-motion";
import {
  Archive,
  ChartLineUp,
  ChatCircleDots,
  FirstAidKit,
  QrCode,
  Sparkle,
  UsersThree,
} from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";
import { useTheme } from "@/lib/useTheme";

type Feature = {
  id: string;
  /** Dark-themed full phone mockup render (transparent background, chassis baked in). */
  image: string;
  /** Light-themed variant of the same render. */
  lightImage: string;
  icon: Icon;
};

function getFeatureImage(feature: Feature, theme: "light" | "dark") {
  return theme === "light" ? feature.lightImage : feature.image;
}

// Label/title/description and the screenshot alt text for each feature are
// translated under "showcase.items.*" in messages/{locale}.json - only the
// stable id, icon, and the theme-specific image paths live here.
const features: Feature[] = [
  { id: "records", image: "/records_dark.png", lightImage: "/records_light.png", icon: Archive },
  { id: "summary", image: "/summary_dark.png", lightImage: "/summary_light.png", icon: Sparkle },
  { id: "analytics", image: "/analytics_dark.png", lightImage: "/analytics_light.png", icon: ChartLineUp },
  {
    id: "emergency",
    image: "/emergencywidget_dark.png",
    lightImage: "/emergencywidget_light.png",
    icon: FirstAidKit,
  },
  {
    id: "family",
    image: "/fammanagement_dark.png",
    lightImage: "/fammanagement_light.png",
    icon: UsersThree,
  },
  { id: "sharing", image: "/sharing_dark.png", lightImage: "/sharing_light.png", icon: QrCode },
  { id: "assistant", image: "/aichat_dark.png", lightImage: "/aichat_light.png", icon: ChatCircleDots },
];

function FeatureEyebrow({ feature }: { feature: Feature }) {
  const t = useTranslations("showcase.items");

  return (
    <span className="inline-flex items-center gap-2 rounded-full border border-[var(--showcase-accent-border)] bg-[var(--showcase-accent-bg)] px-3 py-1 text-xs font-semibold uppercase tracking-wide text-[var(--showcase-accent)]">
      <feature.icon size={14} weight="fill" />
      {t(`${feature.id}.label`)}
    </span>
  );
}

function ProgressIndicator({ index }: { index: number }) {
  return (
    <div className="mt-8 flex items-center gap-3">
      <span className="font-mono text-sm text-[var(--showcase-muted)]">
        <span className="text-[var(--showcase-heading)]">{String(index + 1).padStart(2, "0")}</span>
        {` / ${String(features.length).padStart(2, "0")}`}
      </span>
      <div className="flex flex-1 gap-1.5">
        {features.map((f, i) => (
          <div key={f.id} className="h-1 flex-1 overflow-hidden rounded-full bg-[var(--showcase-track)]">
            <motion.div
              className="h-full rounded-full bg-[var(--showcase-accent)]"
              animate={{ width: i <= index ? "100%" : "0%" }}
              transition={{ duration: 0.4, ease: "easeInOut" }}
            />
          </div>
        ))}
      </div>
    </div>
  );
}

export function StickyFeatureShowcase() {
  const t = useTranslations("showcase.items");
  const sectionRef = useRef<HTMLDivElement>(null);
  const [activeIndex, setActiveIndex] = useState(0);
  const { theme } = useTheme();

  const { scrollYProgress } = useScroll({
    target: sectionRef,
    offset: ["start start", "end end"],
  });

  useMotionValueEvent(scrollYProgress, "change", (progress) => {
    const segment = 1 / features.length;
    const next = Math.min(features.length - 1, Math.max(0, Math.floor(progress / segment)));
    setActiveIndex((current) => (current === next ? current : next));
  });

  const active = features[activeIndex];

  return (
    <section className="bg-[var(--showcase-bg)]">
      {/* Desktop/tablet: phone pinned via `sticky` while scroll progress through
          the tall wrapper below drives which screenshot + copy is active. */}
      <div ref={sectionRef} className="relative hidden md:block" style={{ height: `${features.length * 100}vh` }}>
        <div className="sticky top-20 flex h-[calc(100vh-5rem)] items-center overflow-hidden">
          <div className="mx-auto grid w-full max-w-6xl grid-cols-2 items-center gap-16 px-8 lg:gap-24 lg:px-12">
            <div className="flex justify-center">
              <div className="relative aspect-[940/1672] h-[min(70vh,650px)] w-auto shrink-0">
                {features.map((feature, idx) => (
                  <motion.div
                    key={feature.id}
                    className="absolute inset-0"
                    initial={false}
                    animate={{
                      opacity: idx === activeIndex ? 1 : 0,
                      scale: idx === activeIndex ? 1 : 1.03,
                      y: idx === activeIndex ? 0 : idx < activeIndex ? -14 : 14,
                    }}
                    transition={{ duration: 0.6, ease: "easeInOut" }}
                  >
                    <Image
                      src={getFeatureImage(feature, theme)}
                      alt={t(`${feature.id}.alt`)}
                      fill
                      sizes="(min-width: 1024px) 300px, 270px"
                      priority={idx === 0}
                      className="object-contain drop-shadow-[0_30px_50px_rgba(0,0,0,0.35)]"
                    />
                  </motion.div>
                ))}
              </div>
            </div>

            <div className="min-h-[320px]">
              <AnimatePresence mode="wait">
                <motion.div
                  key={active.id}
                  initial={{ opacity: 0, y: 28, filter: "blur(6px)" }}
                  animate={{ opacity: 1, y: 0, filter: "blur(0px)" }}
                  exit={{ opacity: 0, y: -28, filter: "blur(6px)" }}
                  transition={{ duration: 0.6, ease: "easeInOut" }}
                >
                  <FeatureEyebrow feature={active} />
                  <h3 className="mt-5 text-3xl font-bold tracking-tight text-[var(--showcase-heading)] lg:text-4xl">
                    {t(`${active.id}.title`)}
                  </h3>
                  <p className="mt-4 max-w-md text-base leading-relaxed text-[var(--showcase-muted)]">
                    {t(`${active.id}.description`)}
                  </p>
                </motion.div>
              </AnimatePresence>

              <ProgressIndicator index={activeIndex} />
            </div>
          </div>
        </div>
      </div>

      {/* Mobile: stacked, non-sticky - each feature fades in on its own as it
          scrolls into view instead of pinning the phone. */}
      <div className="flex flex-col items-center gap-16 px-4 py-16 sm:gap-20 sm:px-6 sm:py-20 md:hidden">
        {features.map((feature, idx) => (
          <motion.div
            key={feature.id}
            initial={{ opacity: 0, y: 24, scale: 0.98 }}
            whileInView={{ opacity: 1, y: 0, scale: 1 }}
            viewport={{ once: true, amount: 0.3 }}
            transition={{ duration: 0.6, ease: "easeInOut" }}
            className="flex w-full max-w-sm flex-col items-center text-center"
          >
            <div className="relative aspect-[940/1672] w-[210px] shrink-0 sm:w-[260px]">
              <Image
                src={getFeatureImage(feature, theme)}
                alt={t(`${feature.id}.alt`)}
                fill
                sizes="260px"
                className="object-contain drop-shadow-[0_20px_40px_rgba(0,0,0,0.35)]"
              />
            </div>
            <div className="mt-8">
              <FeatureEyebrow feature={feature} />
            </div>
            <h3 className="mt-4 text-2xl font-bold tracking-tight text-[var(--showcase-heading)]">{t(`${feature.id}.title`)}</h3>
            <p className="mt-3 max-w-sm text-sm leading-relaxed text-[var(--showcase-muted)]">{t(`${feature.id}.description`)}</p>
            <span className="mt-4 font-mono text-xs text-[var(--showcase-muted)]">
              <span className="text-[var(--showcase-heading)]">{String(idx + 1).padStart(2, "0")}</span>
              {` / ${String(features.length).padStart(2, "0")}`}
            </span>
          </motion.div>
        ))}
      </div>
    </section>
  );
}
