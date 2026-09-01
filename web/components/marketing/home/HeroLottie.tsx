"use client";

import { useEffect, useState } from "react";
import Lottie from "lottie-react";

export function HeroLottie() {
  const [animationData, setAnimationData] = useState<object | null>(null);

  useEffect(() => {
    let cancelled = false;
    fetch("/animations/hero-pulse.json")
      .then((res) => res.json())
      .then((data) => {
        if (!cancelled) setAnimationData(data);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (!animationData) {
    return <div className="mx-auto h-[380px] max-w-[380px]" aria-hidden="true" />;
  }

  return (
    <Lottie
      animationData={animationData}
      loop
      autoplay
      style={{ width: "100%", maxWidth: 380, margin: "0 auto" }}
      aria-label="Animated illustration of a health record document"
    />
  );
}
