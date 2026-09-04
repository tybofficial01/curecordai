"use client";

const SCROLL_DURATION_MS = 650;

function easeInOutCubic(t: number) {
  return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
}

// Custom rAF-driven scroll (rather than scrollIntoView({ behavior: "smooth" }))
// so duration/easing match the spec exactly and stay consistent across browsers.
// Offsets by the sticky navbar's actual rendered height so the target section
// isn't left hidden underneath it.
export function scrollToSection(id: string) {
  const found = document.getElementById(id);
  if (!found) return;
  const target: HTMLElement = found;

  const startY = window.scrollY;
  const startTime = performance.now();

  window.history.replaceState(null, "", `#${id}`);

  // Re-measured every frame rather than once up front: right after a
  // cross-page navigation, earlier sections on the homepage are still
  // settling their own scroll-driven layout (ResizeObserver-based pinned
  // tracks), so a target computed only at t=0 can land short. Chasing the
  // live position instead means the very last frame always lands exactly
  // on it, however much the page has shifted underneath the animation.
  function currentTargetY(el: HTMLElement) {
    const headerHeight = document.querySelector("header")?.getBoundingClientRect().height ?? 0;
    return el.getBoundingClientRect().top + window.scrollY - headerHeight - 16;
  }

  function step(now: number) {
    const elapsed = now - startTime;
    const progress = Math.min(elapsed / SCROLL_DURATION_MS, 1);
    const eased = easeInOutCubic(progress);
    const targetY = currentTargetY(target);
    window.scrollTo(0, startY + (targetY - startY) * eased);
    if (progress < 1) requestAnimationFrame(step);
  }

  requestAnimationFrame(step);
}
