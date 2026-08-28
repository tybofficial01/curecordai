import { apiFetch } from "@/lib/api/client";
import type { AppSettings } from "@/lib/api/types";

export function getAppSettings(token: string) {
  return apiFetch<AppSettings>("/settings", { token });
}

export function updateAppSettings(token: string, body: Partial<AppSettings>) {
  return apiFetch<AppSettings>("/settings", { method: "PATCH", token, body });
}
