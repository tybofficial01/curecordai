import { apiFetch } from "@/lib/api/client";
import type { Alert } from "@/lib/api/types";

export function listAlerts(token: string, unreadOnly = false) {
  return apiFetch<Alert[]>("/alerts", { token, query: { unread_only: unreadOnly } });
}

export function getUnreadAlertCount(token: string) {
  return apiFetch<{ unread_count: number }>("/alerts/unread-count", { token });
}

export function markAlertRead(token: string, id: string) {
  return apiFetch<void>(`/alerts/${id}/read`, { method: "POST", token });
}

export function dismissAlert(token: string, id: string) {
  return apiFetch<void>(`/alerts/${id}/dismiss`, { method: "POST", token });
}
