interface BarDatum {
  label: string;
  value: number;
}

export function BarChart({ data }: { data: BarDatum[] }) {
  const max = Math.max(1, ...data.map((d) => d.value));

  return (
    <div className="flex items-end gap-4 sm:gap-6" style={{ height: 200 }}>
      {data.map((datum) => (
        <div key={datum.label} className="flex flex-1 flex-col items-center gap-2">
          <span className="text-xs font-semibold text-ink">{datum.value}</span>
          <div className="flex w-full flex-1 items-end">
            <div
              className="w-full rounded-t-lg bg-primary"
              style={{ height: `${(datum.value / max) * 100}%`, minHeight: datum.value > 0 ? 4 : 0 }}
            />
          </div>
          <span className="text-center text-[11px] leading-tight text-ink-muted">{datum.label}</span>
        </div>
      ))}
    </div>
  );
}
