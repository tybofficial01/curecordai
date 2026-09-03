import { useEffect, useLayoutEffect } from "react";

/**
 * `useLayoutEffect` on the client, `useEffect` on the server (a no-op there, since SSR has no
 * DOM) - avoids React's "useLayoutEffect does nothing on the server" warning while still getting
 * real layout-effect timing in the browser, where it matters.
 *
 * Use this instead of `useEffect` for any effect whose cleanup must finish restoring the DOM
 * *before* React physically removes the subtree on unmount (e.g. reverting a GSAP context that
 * pinned/reparented nodes outside React's own tracking). `useEffect` cleanups run asynchronously
 * after React has already committed its own DOM removals - too late to undo a third-party
 * library's DOM surgery, which is exactly what caused NotFoundError "removeChild ... is not a
 * child of this node" crashes when navigating away from a GSAP-pinned section.
 */
export const useIsomorphicLayoutEffect = typeof window !== "undefined" ? useLayoutEffect : useEffect;
