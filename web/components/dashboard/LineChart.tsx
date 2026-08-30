import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";

interface LineDatum {
  label: string;
  value: number;
}

export function LineChart({ data, unit }: { data: LineDatum[]; unit: string }) {
  const dm = useDashboardMessages();
  const width = 560;
  const height = 200;
  const padding = 28;
  const values = data.map((d) => d.value);
  const min = Math.min(...values);
  const max = Math.max(...values);
  const range = max - min || 1;

  const points = data.map((datum, index) => {
    const x = data.length > 1 ? padding + (index / (data.length - 1)) * (width - padding * 2) : width / 2;
    const y = height - padding - ((datum.value - min) / range) * (height - padding * 2);
    return { x, y, ...datum };
  });

  const path = points.map((p, i) => `${i === 0 ? "M" : "L"}${p.x},${p.y}`).join(" ");

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      className="w-full"
      role="img"
      aria-label={formatMessage(dm.insights.vitalChartAria, { unit })}
    >
      <path d={path} fill="none" stroke="var(--color-primary)" strokeWidth={2.5} strokeLinecap="round" strokeLinejoin="round" />
      {points.map((p) => (
        <g key={p.label}>
          <circle cx={p.x} cy={p.y} r={4} fill="var(--color-primary)" />
          <text x={p.x} y={height - 6} textAnchor="middle" fontSize={11} fill="var(--color-ink-muted)">
            {p.label}
          </text>
          <text x={p.x} y={p.y - 10} textAnchor="middle" fontSize={11} fill="var(--color-ink)" fontWeight={600}>
            {p.value}
          </text>
        </g>
      ))}
    </svg>
  );
}
