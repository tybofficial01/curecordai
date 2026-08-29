"use client";

import { Bell, X, Info, Warning, WarningOctagon } from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { dismissAlert, listAlerts, markAlertRead } from "@/lib/api/alerts";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { EmptyState } from "@/components/dashboard/EmptyState";
import { Skeleton } from "@/components/dashboard/Skeleton";
import type { Alert } from "@/lib/api/types";

const severityIcon: Record<string, typeof Info> = {
  low: Info,
  medium: Warning,
  high: WarningOctagon,
  critical: WarningOctagon,
};

const severityColor: Record<string, string> = {
  low: "text-primary bg-primary-tint",
  medium: "text-warning bg-warning/10",
  high: "text-error bg-error-bg",
  critical: "text-error bg-error-bg",
};

export default function AlertsPage() {
  const { getAccessToken } = useAuth();
  const dm = useDashboardMessages();
  const { data: alerts, isLoading, error, setData } = useCachedResource("alerts", (token) => listAlerts(token));

  async function handleMarkRead(id: string) {
    const token = await getAccessToken();
    if (!token) return;
    await markAlertRead(token, id);
    setData((prev) =>
      prev?.map((a) => (a.id === id ? { ...a, is_read: true, read_at: new Date().toISOString() } : a)) ?? prev
    );
  }

  async function handleDismiss(id: string) {
    const token = await getAccessToken();
    if (!token) return;
    await dismissAlert(token, id);
    setData((prev) => prev?.filter((a) => a.id !== id) ?? prev);
  }

  return (
    <div>
      <PageHeading title={dm.alerts.title} description={dm.alerts.description} />

      {isLoading && (
        <div className="flex flex-col gap-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <Skeleton key={i} className="h-20" />
          ))}
        </div>
      )}
      {error && <p className="text-sm text-error">{error}</p>}

      {alerts && (
        alerts.length === 0 ? (
          <EmptyState icon={Bell} title={dm.alerts.emptyTitle} description={dm.alerts.emptyDescription} />
        ) : (
          <div className="flex flex-col gap-3">
            {alerts.map((alert: Alert) => {
              const Icon = severityIcon[alert.priority] ?? Info;
              return (
                <div
                  key={alert.id}
                  className={`flex items-start gap-4 rounded-2xl border bg-card p-5 ${
                    alert.is_read ? "border-border" : "border-primary"
                  }`}
                >
                  <span className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full ${severityColor[alert.priority] ?? severityColor.low}`}>
                    <Icon size={18} />
                  </span>
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      {!alert.is_read && <span className="h-2 w-2 shrink-0 rounded-full bg-primary" aria-hidden="true" />}
                      <p className="text-sm font-semibold text-ink">{alert.title}</p>
                    </div>
                    <p className="mt-1 text-sm text-ink-muted">{alert.message}</p>
                    <div className="mt-3 flex items-center gap-4">
                      <span className="text-xs text-ink-faint">{new Date(alert.created_at).toLocaleDateString()}</span>
                      {!alert.is_read && (
                        <button
                          type="button"
                          onClick={() => handleMarkRead(alert.id)}
                          className="text-xs font-medium text-primary hover:underline"
                        >
                          {dm.alerts.markAsRead}
                        </button>
                      )}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleDismiss(alert.id)}
                    aria-label={dm.alerts.dismiss}
                    className="shrink-0 rounded-full p-1.5 text-ink-faint hover:bg-surface hover:text-ink max-lg:p-3.5"
                  >
                    <X size={16} />
                  </button>
                </div>
              );
            })}
          </div>
        )
      )}
    </div>
  );
}
