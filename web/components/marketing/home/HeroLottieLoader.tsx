"use client";

import dynamic from "next/dynamic";

export const HeroLottieLoader = dynamic(
  () => import("./HeroLottie").then((m) => m.HeroLottie),
  {
    ssr: false,
    loading: () => <div className="mx-auto h-[380px] max-w-[380px]" aria-hidden="true" />,
  }
);
