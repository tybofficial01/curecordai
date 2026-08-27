import { apiFetch } from "@/lib/api/client";
import type { DoctorInstruction, ShareScope, ShareSession, ShareSessionSummary } from "@/lib/api/types";

export function createShareSession(token: string, shareScope: ShareScope, familyMemberId?: string) {
  return apiFetch<ShareSession>("/share/qr", {
    method: "POST",
    token,
    body: { share_scope: shareScope, family_member_id: familyMemberId ?? null },
  });
}

export function listShareSessions(token: string, familyMemberId?: string) {
  return apiFetch<ShareSessionSummary[]>("/share/sessions", { token, query: { family_member_id: familyMemberId } });
}

export function revokeShareSession(token: string, sessionId: string) {
  return apiFetch<void>(`/share/sessions/${sessionId}`, { method: "DELETE", token });
}

export function listDoctorInstructions(token: string, familyMemberId?: string) {
  return apiFetch<DoctorInstruction[]>("/share/instructions", { token, query: { family_member_id: familyMemberId } });
}

export function markDoctorInstructionRead(token: string, instructionId: string) {
  return apiFetch<void>(`/share/instructions/${instructionId}/read`, { method: "PATCH", token });
}
