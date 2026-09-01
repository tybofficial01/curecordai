"use client";

import { motion, useTransform, cubicBezier, type MotionValue } from "framer-motion";
import { Sparkle } from "@phosphor-icons/react/dist/ssr";

// Matches the requested cubic-bezier(0.22, 1, 0.36, 1) entrance easing exactly.
const entranceEase = cubicBezier(0.22, 1, 0.36, 1);

// Reveal windows, expressed on the same 0→1 pinned-scroll progress as the
// merge/zoom/heading/paragraph phases in HeroFeaturesPhone.tsx. Placed right
// after the phones finish merging (progress 0.3) so the conversation cascades
// in around the now-settled single phone, finishing well before the heading
// phase starts (0.58) - chosen to slot into the existing timeline without
// changing any of its constants. Positioned against the stable, full-height
// stackRef frame (not the phone's own shrinking square), so these never need
// to move or fade again once revealed, however the phone resizes later.
//
// This is scroll-linked rather than time-based (the spec's 700–900ms/120ms
// figures) because the section is scroll-jacked: a mount-triggered or
// whileInView entrance would fire as soon as the pin engages, before the
// phones have even finished merging. The 0.04-wide stagger between windows
// against each card's own 0.06-wide window approximates the same relative
// stagger-to-duration ratio the spec describes.
const PATIENT_START = 0.3;
const PATIENT_END = 0.36;
const AI_REPLY_1_START = 0.34;
const AI_REPLY_1_END = 0.4;
const DOCTOR_START = 0.38;
const DOCTOR_END = 0.44;
const AI_REPLY_2_START = 0.42;
const AI_REPLY_2_END = 0.48;

function ChatBubble({
  role,
  name,
  initial,
  avatarClassName,
  text,
}: {
  role: "user" | "ai";
  name: string;
  initial?: string;
  avatarClassName?: string;
  text: string;
}) {
  const isAI = role === "ai";
  return (
    <div
      className={`flex w-[190px] items-start gap-2.5 rounded-3xl border p-3 text-start backdrop-blur xl:w-[220px] ${
        isAI ? "border-highlight/15 bg-card/60" : "border-primary/15 bg-card/60"
      }`}
      style={{
        boxShadow: "inset 0 1px 0 rgba(255,255,255,0.05), 0 8px 24px rgba(0,0,0,0.22), 0 2px 8px rgba(0,0,0,0.12)",
      }}
    >
      <span className="relative shrink-0">
        {isAI && (
          <span
            aria-hidden
            className="animate-pulse-glow absolute inset-0 rounded-full bg-highlight/40 blur-md"
          />
        )}
        <span
          className={`relative flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold ${
            isAI ? "border border-highlight/50 bg-highlight/15 text-highlight" : avatarClassName
          }`}
        >
          {isAI ? <Sparkle size={16} weight="fill" /> : initial}
        </span>
      </span>
      <span className="min-w-0">
        <span className={`block text-[11px] font-semibold ${isAI ? "text-highlight" : "text-ink"}`}>{name}</span>
        <span className="mt-0.5 block text-xs leading-snug text-ink-muted">{text}</span>
      </span>
    </div>
  );
}

// A CSS animation and a framer-motion `style` prop can't both drive
// `transform` on the same element without fighting each other, so the
// continuous idle float (CSS, on the outer positioned wrapper) and the
// one-time scroll-triggered entrance (framer-motion, on the inner wrapper)
// are split across two nested elements.
function FloatingBubble({
  position,
  floatDelay,
  opacity,
  x,
  y,
  scale,
  children,
}: {
  position: string;
  floatDelay: string;
  opacity: MotionValue<number>;
  x: MotionValue<number>;
  y: MotionValue<number>;
  scale: MotionValue<number>;
  children: React.ReactNode;
}) {
  return (
    <div className={`animate-bubble-float absolute ${position}`} style={{ animationDelay: floatDelay }}>
      <motion.div style={{ opacity, x, y, scale }}>{children}</motion.div>
    </div>
  );
}

/**
 * Floating patient/doctor ↔ AI conversation bubbles flanking the merged
 * phone, evoking an ongoing chat happening around (and inside) the AI chat
 * screen the phone is displaying. Hidden below `lg` per the responsive spec
 * - there's no side room next to the phone on narrower viewports anyway.
 */
export function HeroChatBubbles({ progress }: { progress: MotionValue<number> }) {
  const options = { ease: entranceEase };

  const patientOpacity = useTransform(progress, [PATIENT_START, PATIENT_END], [0, 1], options);
  const patientX = useTransform(progress, [PATIENT_START, PATIENT_END], [-20, 0], options);
  const patientY = useTransform(progress, [PATIENT_START, PATIENT_END], [40, 0], options);
  const patientScale = useTransform(progress, [PATIENT_START, PATIENT_END], [0.96, 1], options);

  const aiReply1Opacity = useTransform(progress, [AI_REPLY_1_START, AI_REPLY_1_END], [0, 1], options);
  const aiReply1X = useTransform(progress, [AI_REPLY_1_START, AI_REPLY_1_END], [20, 0], options);
  const aiReply1Y = useTransform(progress, [AI_REPLY_1_START, AI_REPLY_1_END], [40, 0], options);
  const aiReply1Scale = useTransform(progress, [AI_REPLY_1_START, AI_REPLY_1_END], [0.96, 1], options);

  const doctorOpacity = useTransform(progress, [DOCTOR_START, DOCTOR_END], [0, 1], options);
  const doctorX = useTransform(progress, [DOCTOR_START, DOCTOR_END], [-20, 0], options);
  const doctorY = useTransform(progress, [DOCTOR_START, DOCTOR_END], [40, 0], options);
  const doctorScale = useTransform(progress, [DOCTOR_START, DOCTOR_END], [0.96, 1], options);

  const aiReply2Opacity = useTransform(progress, [AI_REPLY_2_START, AI_REPLY_2_END], [0, 1], options);
  const aiReply2X = useTransform(progress, [AI_REPLY_2_START, AI_REPLY_2_END], [20, 0], options);
  const aiReply2Y = useTransform(progress, [AI_REPLY_2_START, AI_REPLY_2_END], [40, 0], options);
  const aiReply2Scale = useTransform(progress, [AI_REPLY_2_START, AI_REPLY_2_END], [0.96, 1], options);

  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 hidden lg:block">
      <FloatingBubble
        position="left-2 top-[18%] xl:left-6 2xl:left-12"
        floatDelay="0s"
        opacity={patientOpacity}
        x={patientX}
        y={patientY}
        scale={patientScale}
      >
        <ChatBubble
          role="user"
          name="Patient"
          initial="P"
          avatarClassName="bg-primary text-primary-foreground"
          text="Can you explain my blood report?"
        />
      </FloatingBubble>

      <FloatingBubble
        position="right-2 top-[10%] xl:right-6 2xl:right-12"
        floatDelay="-1.5s"
        opacity={aiReply1Opacity}
        x={aiReply1X}
        y={aiReply1Y}
        scale={aiReply1Scale}
      >
        <ChatBubble
          role="ai"
          name="CurecordAI"
          text="Vitamin D levels are below normal. Consider discussing supplements with your doctor."
        />
      </FloatingBubble>

      <FloatingBubble
        position="left-2 top-[46%] xl:left-6 2xl:left-12"
        floatDelay="-3s"
        opacity={doctorOpacity}
        x={doctorX}
        y={doctorY}
        scale={doctorScale}
      >
        <ChatBubble
          role="user"
          name="Doctor"
          initial="Dr"
          avatarClassName="bg-info text-primary-foreground"
          text="Share his current medications."
        />
      </FloatingBubble>

      <FloatingBubble
        position="right-2 top-[40%] xl:right-6 2xl:right-12"
        floatDelay="-4.5s"
        opacity={aiReply2Opacity}
        x={aiReply2X}
        y={aiReply2Y}
        scale={aiReply2Scale}
      >
        <ChatBubble role="ai" name="CurecordAI" text="His records show hypertension and current medications." />
      </FloatingBubble>
    </div>
  );
}
