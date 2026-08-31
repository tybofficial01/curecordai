"use client";

import { Heartbeat, Pill, Warning, Flask, Sparkle, FileText } from "@phosphor-icons/react/dist/ssr";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { getHealthOverview } from "@/lib/api/insights";
import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { EmptyState } from "@/components/dashboard/EmptyState";
import { Skeleton } from "@/components/dashboard/Skeleton";

function capitalize(s: string | null): string {
  if (!s) return "";
  return s[0].toUpperCase() + s.slice(1).replaceAll("-", " ");
}

function Section({ icon: Icon, title, children }: { icon: typeof Heartbeat; title: string; children: React.ReactNode }) {
  return (
    <div className="mt-5">
      <div className="flex items-center gap-2">
        <Icon size={16} className="text-primary" />
        <h2 className="text-sm font-semibold text-ink">{title}</h2>
      </div>
      <div className="mt-2 divide-y divide-border overflow-hidden rounded-2xl border border-border bg-card">
        {children}
      </div>
    </div>
  );
}

function Tile({ title, subtitle, trailing, trailingClass }: { title: string; subtitle?: string | null; trailing?: string | null; trailingClass?: string }) {
  return (
    <div className="flex items-center justify-between gap-4 px-4 py-3">
      <div className="min-w-0">
        <p className="text-sm font-semibold text-ink">{title}</p>
        {subtitle && <p className="text-xs text-ink-muted">{subtitle}</p>}
      </div>
      {trailing && <span className={`shrink-0 text-xs font-semibold ${trailingClass ?? "text-ink-muted"}`}>{trailing}</span>}
    </div>
  );
}

export default function HealthSummaryPage() {
  const { profile: activeProfile } = useActiveProfile();
  const dm = useDashboardMessages();
  const scopeId = activeProfile.isOwnerMode ? null : activeProfile.memberId;
  const { data, isLoading, error } = useCachedResource(`health-overview-${scopeId ?? "self"}`, (token) =>
    getHealthOverview(token, scopeId ?? undefined)
  );

  const title = activeProfile.isOwnerMode
    ? dm.healthSummary.title
    : formatMessage(dm.healthSummary.memberTitle, { name: activeProfile.memberName ?? "" });

  if (isLoading) {
    return (
      <div>
        <Skeleton className="h-7 w-48" />
        <Skeleton className="mt-2 h-4 w-96" />
        <Skeleton className="mt-6 h-32" />
        <Skeleton className="mt-5 h-24" />
      </div>
    );
  }
  if (error || !data) return <p className="text-sm text-error">{error ?? dm.healthSummary.loadError}</p>;

  const { narrative_summary, conditions, medications, allergies, recent_observations } = data;
  const isEmpty =
    !narrative_summary && conditions.length === 0 && medications.length === 0 && allergies.length === 0 && recent_observations.length === 0;

  return (
    <div>
      <PageHeading
        title={title}
        description={dm.healthSummary.description}
      />

      {isEmpty ? (
        <EmptyState
          icon={FileText}
          title={
            activeProfile.isOwnerMode
              ? dm.healthSummary.emptyTitle
              : formatMessage(dm.healthSummary.emptyMemberTitle, { name: activeProfile.memberName ?? "" })
          }
          description={dm.healthSummary.emptyDescription}
        />
      ) : (
        <>
          {narrative_summary && (
            <div className="rounded-2xl border border-primary/20 bg-gradient-to-br from-primary/10 to-primary/[0.03] p-5">
              <div className="flex items-center gap-2">
                <Sparkle size={18} className="text-primary" />
                <h2 className="text-sm font-bold text-primary">{dm.healthSummary.overviewTitle}</h2>
              </div>
              <p className="mt-3 text-sm leading-relaxed text-ink">{narrative_summary}</p>
            </div>
          )}

          {conditions.length > 0 && (
            <Section icon={Heartbeat} title={dm.healthSummary.activeConditions}>
              {conditions.map((c, i) => (
                <Tile key={i} title={c.condition_name} subtitle={capitalize(c.clinical_status)} trailing={c.icd11_code} />
              ))}
            </Section>
          )}

          {medications.length > 0 && (
            <Section icon={Pill} title={dm.healthSummary.currentMedications}>
              {medications.map((m, i) => (
                <Tile
                  key={i}
                  title={m.medication_name_raw}
                  subtitle={[m.dosage_instruction, m.dose_frequency].filter(Boolean).join(" · ")}
                />
              ))}
            </Section>
          )}

          {allergies.length > 0 && (
            <Section icon={Warning} title={dm.healthSummary.allergies}>
              {allergies.map((a, i) => (
                <Tile
                  key={i}
                  title={a.substance_name}
                  subtitle={a.reaction_description}
                  trailing={a.criticality}
                  trailingClass={a.criticality === "high" ? "text-error" : "text-warning"}
                />
              ))}
            </Section>
          )}

          {recent_observations.length > 0 && (
            <Section icon={Flask} title={dm.healthSummary.recentLabs}>
              {recent_observations.slice(0, 10).map((o, i) => {
                const value = o.value_quantity != null ? `${o.value_quantity} ${o.value_unit ?? ""}`.trim() : o.value_string ?? "—";
                return <Tile key={i} title={o.observation_name} trailing={value} />;
              })}
            </Section>
          )}

          <p className="mt-5 rounded-xl border border-primary/15 bg-primary/5 p-3.5 text-xs leading-relaxed text-ink-muted">
            {dm.healthSummary.disclaimer}
          </p>
        </>
      )}
    </div>
  );
}
