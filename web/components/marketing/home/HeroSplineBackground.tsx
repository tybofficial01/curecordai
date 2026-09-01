"use client";

import { Suspense } from "react";
import dynamic from "next/dynamic";

// The package's "/next" entry point (dist/react-spline-next.js) imports from
// "next/image" in a way that only resolves against Next 15's export map, not
// this project's Next 14.2 - it 404s at module-resolution time. The base
// export has no such dependency, so it's used here instead, still wrapped in
// next/dynamic with ssr:false since Spline touches window/canvas/WebGL,
// which would throw during Next's server render if this ever attempted SSR.
const Spline = dynamic(() => import("@splinetool/react-spline"), { ssr: false });

const SPLINE_SCENE = "https://prod.spline.design/Slk6b8kz3LRlKiyk/scene.splinecode";

// Sits behind the hero's intro copy, confined to one viewport tall (the section
// itself is much taller further down, for the pinned phone-merge showcase).
export function HeroSplineBackground() {
  return (
    <div className="absolute inset-x-0 top-0 z-0 h-screen w-full overflow-hidden">
      <Suspense fallback={<div className="absolute inset-0 bg-black" />}>
        <Spline scene={SPLINE_SCENE} className="h-full w-full" />
      </Suspense>
      <div className="pointer-events-none absolute inset-0 z-[1] bg-black/30" />
    </div>
  );
}
