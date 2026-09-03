"use client";

import { useLayoutEffect, useRef, useState, type ReactNode, type RefObject } from "react";
import { createPortal } from "react-dom";

interface PopoverProps {
  open: boolean;
  onClose: () => void;
  /** Element the popover is anchored to - used to compute its fixed-position coordinates. */
  triggerRef: RefObject<HTMLElement>;
  children: ReactNode;
  /** Horizontal alignment relative to the trigger's edge. */
  align?: "start" | "end";
  /** Vertical placement relative to the trigger. */
  side?: "top" | "bottom";
  /** Gap between the trigger and the popover, in pixels. */
  offset?: number;
  className?: string;
}

/**
 * Renders a dropdown/popover into document.body via a portal, positioned against its trigger's
 * bounding box with `position: fixed`. Sidebars and scrollable panels create their own stacking
 * contexts (overflow-y-auto, z-index, etc.) that trap absolutely-positioned children beneath
 * sibling panels - a portal sidesteps that entirely instead of trying to out-z-index it locally.
 */
export function Popover({
  open,
  onClose,
  triggerRef,
  children,
  align = "start",
  side = "bottom",
  offset = 8,
  className = "",
}: PopoverProps) {
  const popoverRef = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState<{ top: number; left: number } | null>(null);

  useLayoutEffect(() => {
    if (!open) return;

    function updatePosition() {
      const trigger = triggerRef.current;
      const popover = popoverRef.current;
      if (!trigger) return;
      const triggerRect = trigger.getBoundingClientRect();
      const popoverWidth = popover?.offsetWidth ?? 0;
      const popoverHeight = popover?.offsetHeight ?? 0;
      // "start"/"end" are reading-order relative, not physical left/right, so they need to flip
      // with the document's direction - otherwise an RTL page (e.g. Urdu, with the sidebar
      // docked to the right) anchors the popover from the trigger's left edge and it runs off
      // the right side of the screen.
      const isRtl = document.documentElement.dir === "rtl";
      const alignsToRightEdge = isRtl ? align === "start" : align === "end";
      let left = alignsToRightEdge ? triggerRect.right - popoverWidth : triggerRect.left;
      // Clamp to the viewport so the popover never overflows the screen, regardless of direction
      // or how narrow the device is.
      const margin = 8;
      left = Math.min(Math.max(left, margin), window.innerWidth - popoverWidth - margin);
      const top = side === "top" ? triggerRect.top - popoverHeight - offset : triggerRect.bottom + offset;
      setPosition({ top, left });
    }

    updatePosition();
    // Capture phase: scrolling inside a nested panel (e.g. the conversation list) doesn't bubble.
    window.addEventListener("scroll", updatePosition, true);
    window.addEventListener("resize", updatePosition);
    return () => {
      window.removeEventListener("scroll", updatePosition, true);
      window.removeEventListener("resize", updatePosition);
    };
  }, [open, triggerRef, align, side, offset]);

  useLayoutEffect(() => {
    if (!open) return;
    function handlePointerDown(event: MouseEvent) {
      const target = event.target as Node;
      if (triggerRef.current?.contains(target)) return;
      if (popoverRef.current?.contains(target)) return;
      onClose();
    }
    document.addEventListener("mousedown", handlePointerDown);
    return () => document.removeEventListener("mousedown", handlePointerDown);
  }, [open, onClose, triggerRef]);

  if (!open || typeof document === "undefined") return null;

  return createPortal(
    <div
      ref={popoverRef}
      style={{
        position: "fixed",
        top: position?.top ?? 0,
        left: position?.left ?? 0,
        visibility: position ? "visible" : "hidden",
      }}
      className={`z-[1000] rounded-xl border border-border bg-card shadow-lg ${className}`}
    >
      {children}
    </div>,
    document.body
  );
}
