"use client";

import type { ReactNode } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import {
  ArrowLeft,
  Sparkle,
  CheckCircle,
  WarningCircle,
  XCircle,
  Info,
  ChatCircleDots,
  CloudSlash,
  Drop,
  ChartBar,
  Gauge,
  ChartScatter,
  Funnel,
  UserGear,
  Flask,
} from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";
import { useAsyncResource } from "@/lib/hooks/useAsyncResource";
import { getRecordFull } from "@/lib/api/records";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";
import type { RecordAiAnalysisParameter } from "@/lib/api/types";

// Mirrors fe/lib/features/records/screens/ai_summary_screen.dart's _paramIcon() so the same
// parameter name maps to the same icon on both platforms. Renders the element directly (rather
// than returning a component reference) so no component identity is computed during render.
function ParameterIcon({ name, size }: { name: string; size: number }) {
  const lower = name.toLowerCase();
  if (["hemoglobin", "haemoglobin", "hgb", "rbc", "iron"].some((k) => lower.includes(k))) return <Drop size={size} />;
  if (["glucose", "sugar", "hba1c"].some((k) => lower.includes(k))) return <Drop size={size} />;
  if (["cholesterol", "ldl", "hdl", "triglyceride"].some((k) => lower.includes(k))) return <ChartBar size={size} />;
  if (["pressure", "bp", "systolic"].some((k) => lower.includes(k))) return <Gauge size={size} />;
  if (["platelet", "wbc", "leukocyte"].some((k) => lower.includes(k))) return <ChartScatter size={size} />;
  if (["creatinine", "urea", "kidney", "gfr"].some((k) => lower.includes(k))) return <Funnel size={size} />;
  if (["thyroid", "tsh", "t3", "t4"].some((k) => lower.includes(k))) return <UserGear size={size} />;
  return <Flask size={size} />;
}

const overallStyles: Record<string, { colorClass: string; bgClass: string; borderClass: string; icon: Icon }> = {
  Good: { colorClass: "text-success", bgClass: "bg-success/[0.08]", borderClass: "border-success/25", icon: CheckCircle },
  Fair: { colorClass: "text-warning", bgClass: "bg-warning/[0.08]", borderClass: "border-warning/25", icon: WarningCircle },
  Poor: { colorClass: "text-error", bgClass: "bg-error/[0.08]", borderClass: "border-error/25", icon: XCircle },
};

const parameterStyles: Record<string, { text: string; iconBg: string; chipBg: string; dot: string }> = {
  Healthy: { text: "text-success", iconBg: "bg-success/10", chipBg: "bg-success/[0.12]", dot: "bg-success" },
  Optimal: { text: "text-primary", iconBg: "bg-primary/10", chipBg: "bg-primary/[0.12]", dot: "bg-primary" },
  Monitoring: { text: "text-warning", iconBg: "bg-warning/10", chipBg: "bg-warning/[0.12]", dot: "bg-warning" },
  Attention: { text: "text-error", iconBg: "bg-error/10", chipBg: "bg-error/[0.12]", dot: "bg-error" },
};
const defaultParameterStyle = {
  text: "text-ink-faint",
  iconBg: "bg-ink-faint/10",
  chipBg: "bg-ink-faint/[0.12]",
  dot: "bg-ink-faint",
};

export default function AiReportSummaryPage() {
  const params = useParams<{ id: string }>();
  const dm = useDashboardMessages();
  const { data: record, isLoading, error, refetch } = useAsyncResource(
    (token) => getRecordFull(token, params.id),
    [params.id]
  );

  return (
    <div className="mx-auto max-w-2xl">
      <Link
        href={`/dashboard/vault/${params.id}`}
        className="flex items-center gap-2 text-sm font-medium text-ink-muted hover:text-primary"
      >
        <ArrowLeft size={16} /> {dm.aiReport.backToDocument}
      </Link>

      <div className="mt-4 flex items-center gap-2">
        <Sparkle size={18} className="text-primary" weight="fill" />
        <h1 className="text-xl font-bold text-ink">{dm.aiReport.title}</h1>
      </div>

      <div className="mt-6">
        {isLoading && (
          <div className="flex justify-center py-16">
            <span className="h-8 w-8 animate-spin rounded-full border-2 border-primary/30 border-t-primary" />
          </div>
        )}

        {!isLoading && (error || !record) && (
          <CenteredState
            icon={CloudSlash}
            title={dm.aiReport.loadErrorTitle}
            description=""
            action={
              <button
                type="button"
                onClick={() => refetch()}
                className="rounded-full border border-border px-6 py-2.5 text-sm font-semibold text-ink hover:bg-surface"
              >
                {dm.common.retry}
              </button>
            }
          />
        )}

        {!isLoading && record && record.processing_status === "processing" && (
          <CenteredState
            icon={Sparkle}
            iconTint
            title={dm.aiReport.analysingTitle}
            description={dm.aiReport.analysingDescription}
          />
        )}

        {!isLoading && record && record.processing_status === "failed" && (
          <CenteredState
            icon={WarningCircle}
            iconClassName="text-error"
            title={dm.aiReport.failedTitle}
            description={dm.aiReport.failedDescription}
            action={
              <Link
                href="/dashboard/assistant"
                className="flex items-center gap-2 rounded-full bg-primary px-6 py-2.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              >
                <ChatCircleDots size={16} /> {dm.aiReport.askAiInstead}
              </Link>
            }
          />
        )}

        {!isLoading &&
          record &&
          record.processing_status !== "processing" &&
          record.processing_status !== "failed" &&
          !record.ai_analysis && (
            <CenteredState
              icon={Flask}
              iconTint
              title={dm.aiReport.noParametersTitle}
              description={dm.aiReport.noParametersDescription}
              action={
                <div className="flex w-full flex-col gap-3">
                  <Link
                    href="/dashboard/assistant"
                    className="flex items-center justify-center gap-2 rounded-2xl bg-primary px-6 py-3.5 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
                  >
                    <Sparkle size={16} weight="fill" /> {dm.aiReport.continueInChat}
                  </Link>
                  <Link
                    href={`/dashboard/vault/${params.id}`}
                    className="flex items-center justify-center rounded-2xl border border-border px-6 py-3.5 text-sm font-semibold text-ink hover:bg-surface"
                  >
                    {dm.aiReport.viewRecordDetails}
                  </Link>
                </div>
              }
            />
          )}

        {!isLoading &&
          record &&
          record.processing_status !== "processing" &&
          record.processing_status !== "failed" &&
          record.ai_analysis && <AnalysisContent analysis={record.ai_analysis} dm={dm} />}
      </div>
    </div>
  );
}

function CenteredState({
  icon: StateIcon,
  iconTint,
  iconClassName,
  title,
  description,
  action,
}: {
  icon: Icon;
  iconTint?: boolean;
  iconClassName?: string;
  title: string;
  description: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-4 px-4 py-16 text-center">
      {iconTint ? (
        <span className="flex h-20 w-20 items-center justify-center rounded-full bg-primary/10 text-primary">
          <StateIcon size={40} weight={StateIcon === Sparkle ? "fill" : "regular"} />
        </span>
      ) : (
        <StateIcon size={48} className={iconClassName ?? "text-ink-faint"} />
      )}
      <div>
        <h2 className="text-lg font-semibold text-ink">{title}</h2>
        {description && <p className="mt-2 max-w-sm text-[13px] leading-relaxed text-ink-muted">{description}</p>}
      </div>
      {action && <div className="mt-2 w-full max-w-xs">{action}</div>}
    </div>
  );
}

function AnalysisContent({
  analysis,
  dm,
}: {
  analysis: { overall_status: string; overall_explanation: string; parameters: RecordAiAnalysisParameter[] };
  dm: DashboardMessages;
}) {
  const style = overallStyles[analysis.overall_status] ?? overallStyles.Good;
  const OverallIcon = style.icon;

  return (
    <div className="flex flex-col gap-4">
      <div className={`rounded-[14px] border p-4 ${style.bgClass} ${style.borderClass}`}>
        <p className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">{dm.aiReport.analysisResult}</p>
        <div className="mt-2 flex items-center gap-2.5">
          <OverallIcon size={28} weight="fill" className={style.colorClass} />
          <p className={`text-xl font-bold ${style.colorClass}`}>
            {formatMessage(dm.aiReport.overall, { status: analysis.overall_status })}
          </p>
        </div>
        {analysis.overall_explanation && (
          <p className="mt-2 text-[13px] leading-relaxed text-ink-muted">{analysis.overall_explanation}</p>
        )}
      </div>

      {analysis.parameters.map((parameter, index) => (
        <ParameterCard key={index} parameter={parameter} />
      ))}

      <div className="flex items-start gap-2 rounded-xl border border-primary/15 bg-primary/[0.05] p-3.5">
        <Info size={14} className="mt-0.5 shrink-0 text-ink-muted" />
        <p className="text-[11px] leading-relaxed text-ink-muted">{dm.aiReport.disclaimer}</p>
      </div>

      <Link
        href="/dashboard/assistant"
        className="flex items-center justify-center gap-2 rounded-2xl bg-primary px-6 py-4 text-[15px] font-semibold text-primary-foreground hover:bg-primary/90"
      >
        <Sparkle size={18} weight="fill" /> {dm.aiReport.continueExplanation}
      </Link>
    </div>
  );
}

function ParameterCard({ parameter }: { parameter: RecordAiAnalysisParameter }) {
  const style = parameterStyles[parameter.status] ?? defaultParameterStyle;

  return (
    <div className="rounded-xl border border-border bg-card p-4">
      <div className="flex items-center gap-2.5">
        <span className={`flex h-9 w-9 shrink-0 items-center justify-center rounded-lg ${style.iconBg} ${style.text}`}>
          <ParameterIcon name={parameter.name} size={18} />
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-ink">{parameter.name}</p>
          {parameter.value && (
            <p className="text-xs text-ink-muted">
              {parameter.value} {parameter.unit}
            </p>
          )}
        </div>
        <span className={`flex shrink-0 items-center gap-1.5 rounded-full px-2.5 py-1 ${style.chipBg}`}>
          <span className={`h-1.5 w-1.5 rounded-full ${style.dot}`} />
          <span className={`text-[11px] font-semibold ${style.text}`}>{parameter.status}</span>
        </span>
      </div>
      {parameter.explanation && (
        <p className="mt-2.5 text-[13px] leading-relaxed text-ink-muted">{parameter.explanation}</p>
      )}
    </div>
  );
}
