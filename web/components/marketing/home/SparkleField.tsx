type Sparkle = {
  top: string;
  left: string;
  size: number;
  delay: number;
  duration: number;
};

// Fixed, hand-tuned positions (not Math.random()) so server and client markup match exactly.
const sparkles: Sparkle[] = [
  { top: "8%", left: "12%", size: 2, delay: 0, duration: 5 },
  { top: "18%", left: "82%", size: 3, delay: 1.2, duration: 6 },
  { top: "26%", left: "38%", size: 2, delay: 2.4, duration: 4.5 },
  { top: "34%", left: "64%", size: 2, delay: 0.6, duration: 5.5 },
  { top: "42%", left: "6%", size: 3, delay: 3, duration: 6.5 },
  { top: "48%", left: "92%", size: 2, delay: 1.8, duration: 5 },
  { top: "56%", left: "22%", size: 2, delay: 4, duration: 4.5 },
  { top: "62%", left: "74%", size: 3, delay: 0.3, duration: 6 },
  { top: "68%", left: "48%", size: 2, delay: 2.7, duration: 5.5 },
  { top: "76%", left: "16%", size: 2, delay: 1.5, duration: 5 },
  { top: "82%", left: "88%", size: 3, delay: 3.6, duration: 6.5 },
  { top: "14%", left: "56%", size: 2, delay: 2, duration: 4.5 },
  { top: "90%", left: "34%", size: 2, delay: 0.9, duration: 5.5 },
  { top: "5%", left: "70%", size: 2, delay: 3.3, duration: 5 },
];

export function SparkleField() {
  return (
    <div aria-hidden className="pointer-events-none absolute inset-0 z-0 overflow-hidden">
      {sparkles.map((s, i) => (
        <span
          key={i}
          className="animate-sparkle absolute rounded-full bg-highlight"
          style={{
            top: s.top,
            left: s.left,
            width: s.size,
            height: s.size,
            animationDelay: `${s.delay}s`,
            animationDuration: `${s.duration}s`,
          }}
        />
      ))}
    </div>
  );
}
