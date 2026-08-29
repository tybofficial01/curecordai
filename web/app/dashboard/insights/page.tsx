"use client";

import { getObservationTrend } from "@/lib/api/insights";
import { listRecords } from "@/lib/api/records";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { BarChart } from "@/components/dashboard/BarChart";
import { LineChart } from "@/components/dashboard/LineChart";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { RECORD_TYPES, type RecordType } from "@/lib/api/types";

// The chart axis is tight, so this view abbreviates "Discharge Summary" to just
// "Discharge" - hence its own lookup rather than reusing dm.recordTypes wholesale.
function recordTypeLabel(dm: DashboardMessages, type: RecordType): string {
  return type === "discharge_summary" ? dm.insights.dischargeShort : dm.recordTypes[type];
}

// LOINC codes only - the human-readable name comes back from the backend on the
// trend itself (`observation_name`), already in the account's language.
const TRACKED_VITALS = [{ loincCode: "29463-7" }, { loincCode: "8480-6" }];

async function loadInsights(token: string, familyMemberId?: string | null) {
  const scopeId = familyMemberId ?? undefined;
  const [records, ...trends] = await Promise.all([
    listRecords(token, { family_member_id: scopeId }),
    ...TRACKED_VITALS.map((v) => getObservationTrend(token, v.loincCode, 90, scopeId)),
  ]);
  return { records, trends };
}

export default function InsightsPage() {
  const { profile: activeProfile } = useActiveProfile();
  const dm = useDashboardMessages();
  const scopeId = activeProfile.isOwnerMode ? null : activeProfile.memberId;
  const { data, isLoading, error } = useCachedResource(`insights-${scopeId ?? "self"}`, (token) =>
    loadInsights(token, scopeId)
  );

  if (isLoading) {
    return (
      <div>
        <Skeleton className="h-7 w-32" />
        <Skeleton className="mt-2 h-4 w-96" />
        <div className="mt-6 grid gap-6 lg:grid-cols-2">
          <Skeleton className="h-64" />
          <Skeleton className="h-64" />
        </div>
      </div>
    );
  }
  if (error || !data) return <p className="text-sm text-error">{error ?? dm.insights.loadError}</p>;

  const recordsByType = RECORD_TYPES.map((type) => ({
    label: recordTypeLabel(dm, type),
    value: data.records.filter((r) => r.record_type === type).length,
  })).filter((entry) => entry.value > 0);

  const trendsWithData = data.trends.filter((trend) => trend.points.length > 0);

  return (
    <div>
      <PageHeading
        title={dm.insights.title}
        description={dm.insights.description}
      />

      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-2xl border border-border bg-card p-6">
          <h2 className="text-sm font-semibold text-ink">{dm.insights.recordsByType}</h2>
          <p className="text-xs text-ink-muted">{dm.insights.recordsByTypeDescription}</p>
          <div className="mt-6">
            {recordsByType.length === 0 ? (
              <p className="text-sm text-ink-muted">{dm.insights.noRecords}</p>
            ) : (
              <BarChart data={recordsByType} />
            )}
          </div>
        </div>

        {trendsWithData.length === 0 ? (
          <div className="rounded-2xl border border-border bg-card p-6">
            <h2 className="text-sm font-semibold text-ink">{dm.insights.vitalTrends}</h2>
            <p className="mt-6 text-sm text-ink-muted">{dm.insights.noTrends}</p>
          </div>
        ) : (
          trendsWithData.map((trend) => (
            <div key={trend.loinc_code} className="rounded-2xl border border-border bg-card p-6">
              <h2 className="text-sm font-semibold text-ink">{trend.observation_name}</h2>
              <p className="text-xs text-ink-muted">{dm.insights.last90Days}</p>
              <div className="mt-6">
                <LineChart
                  data={trend.points.map((p) => ({
                    label: new Date(p.date).toLocaleDateString(undefined, { month: "short", day: "numeric" }),
                    value: p.value,
                  }))}
                  unit={trend.points[0]?.unit ?? ""}
                />
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
