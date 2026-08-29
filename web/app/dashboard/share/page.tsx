"use client";

import { useState } from "react";
import { QRCodeSVG } from "qrcode.react";
import { QrCode, Copy, XCircle, CheckCircle, EnvelopeSimple } from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { useTheme } from "@/lib/useTheme";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { useConfirm } from "@/lib/dialog/ConfirmDialogProvider";
import {
  createShareSession,
  listDoctorInstructions,
  listShareSessions,
  markDoctorInstructionRead,
  revokeShareSession,
} from "@/lib/api/sharing";
import { ApiError } from "@/lib/api/client";
import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { EmptyState } from "@/components/dashboard/EmptyState";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { SHARE_SCOPES, type DoctorInstruction, type ShareScope, type ShareSession } from "@/lib/api/types";

async function loadShareData(token: string, familyMemberId?: string) {
  const [sessions, instructions] = await Promise.all([
    listShareSessions(token, familyMemberId),
    listDoctorInstructions(token, familyMemberId),
  ]);
  return { sessions, instructions };
}

export default function SharePage() {
  const { getAccessToken } = useAuth();
  const { theme } = useTheme();
  const confirm = useConfirm();
  const dm = useDashboardMessages();
  const { profile: activeProfile } = useActiveProfile();
  const scopeId = activeProfile.isOwnerMode ? null : activeProfile.memberId;
  const { data, isLoading: sessionsLoading, setData } = useCachedResource(
    `share-data-${scopeId ?? "self"}`,
    (token) => loadShareData(token, scopeId ?? undefined)
  );
  const sessions = data?.sessions ?? null;
  const instructions = data?.instructions ?? null;
  const [expandedInstructionId, setExpandedInstructionId] = useState<string | null>(null);
  const subjectName = activeProfile.isOwnerMode
    ? dm.share.subjectYour
    : formatMessage(dm.share.subjectMember, { name: activeProfile.memberName ?? "" });

  const [scope, setScope] = useState<ShareScope>("full");
  const [latestSession, setLatestSession] = useState<ShareSession | null>(null);
  const [copied, setCopied] = useState(false);
  const [error, setError] = useState("");
  const [generating, setGenerating] = useState(false);

  async function handleGenerate() {
    setError("");
    setGenerating(true);
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      const session = await createShareSession(token, scope, scopeId ?? undefined);
      setLatestSession(session);
      setCopied(false);
      setData((prev) =>
        prev
          ? {
              ...prev,
              sessions: [
                { id: session.id, scope: session.share_scope, status: session.status, expires_at: session.expires_at },
                ...prev.sessions,
              ],
            }
          : prev
      );
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.share.generateError);
    } finally {
      setGenerating(false);
    }
  }

  async function handleCopy() {
    if (!latestSession) return;
    try {
      await navigator.clipboard.writeText(latestSession.qr_url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      setCopied(false);
    }
  }

  async function handleRevoke(sessionId: string) {
    const confirmed = await confirm({
      title: dm.share.revokeConfirmTitle,
      description: dm.share.revokeConfirmDescription,
      confirmLabel: dm.share.revokeLabel,
      cancelLabel: dm.common.cancel,
      destructive: true,
    });
    if (!confirmed) return;
    const token = await getAccessToken();
    if (!token) return;
    await revokeShareSession(token, sessionId);
    setData((prev) => (prev ? { ...prev, sessions: prev.sessions.filter((s) => s.id !== sessionId) } : prev));
  }

  async function handleToggleInstruction(instruction: DoctorInstruction) {
    const next = expandedInstructionId === instruction.id ? null : instruction.id;
    setExpandedInstructionId(next);
    if (next && !instruction.seen_at) {
      const authToken = await getAccessToken();
      if (!authToken) return;
      await markDoctorInstructionRead(authToken, instruction.id);
      setData((prev) =>
        prev
          ? {
              ...prev,
              instructions: prev.instructions.map((i) =>
                i.id === instruction.id ? { ...i, seen_at: new Date().toISOString() } : i
              ),
            }
          : prev
      );
    }
  }

  return (
    <div>
      <PageHeading
        title={dm.share.title}
        description={formatMessage(dm.share.description, { subject: subjectName })}
      />

      <div className="grid gap-8 lg:grid-cols-2">
        <div className="rounded-2xl border border-border bg-card p-6">
          <h2 className="text-sm font-semibold text-ink">{dm.share.whatToShare}</h2>
          <div className="mt-3 flex flex-col gap-2">
            {SHARE_SCOPES.map((option) => (
              <label
                key={option}
                className={`flex cursor-pointer items-center gap-3 rounded-xl border px-4 py-3 text-sm font-medium ${
                  scope === option ? "border-primary bg-primary-tint text-primary" : "border-border text-ink"
                }`}
              >
                <input
                  type="radio"
                  name="scope"
                  value={option}
                  checked={scope === option}
                  onChange={() => setScope(option)}
                  className="accent-primary"
                />
                {dm.share.scopes[option]}
              </label>
            ))}
          </div>

          <p className="mt-4 text-xs text-ink-muted">
            {formatMessage(dm.share.sharingNote, { subject: subjectName })}
          </p>

          <p className="mt-2 text-xs text-ink-muted">{dm.share.expiryNote}</p>

          {error && <p className="mt-3 text-sm font-medium text-error">{error}</p>}

          <button
            type="button"
            onClick={handleGenerate}
            disabled={generating}
            className="mt-6 flex w-full items-center justify-center gap-2 rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground hover:bg-primary/90 disabled:opacity-70"
          >
            <QrCode size={20} /> {generating ? dm.share.generating : dm.share.generate}
          </button>
        </div>

        <div className="flex flex-col items-center justify-center rounded-2xl border border-border bg-card p-6 text-center">
          {latestSession ? (
            <>
              <div className="rounded-lg bg-card p-3">
                <QRCodeSVG
                  value={latestSession.qr_url}
                  size={200}
                  fgColor={theme === "dark" ? "#F2F7F6" : "#14201E"}
                  bgColor={theme === "dark" ? "#16201F" : "#FFFFFF"}
                  level="M"
                />
              </div>
              <p className="mt-4 text-sm font-semibold text-ink">{dm.share.scopes[latestSession.share_scope]}</p>
              <p className="mt-1 text-xs text-ink-muted">
                {formatMessage(dm.share.expires, { when: new Date(latestSession.expires_at).toLocaleString() })}
              </p>
              <button
                type="button"
                onClick={handleCopy}
                className="mt-4 flex items-center gap-2 rounded-full border border-border px-4 py-2 text-xs font-medium text-ink hover:bg-surface"
              >
                {copied ? <CheckCircle size={14} className="text-success" /> : <Copy size={14} />}
                {copied ? dm.share.linkCopied : dm.share.copyLink}
              </button>
            </>
          ) : (
            <>
              <QrCode size={48} className="text-primary" weight="duotone" />
              <p className="mt-3 max-w-xs text-sm text-ink-muted">{dm.share.qrPlaceholder}</p>
            </>
          )}
        </div>
      </div>

      <div className="mt-10">
        <h2 className="text-lg font-semibold text-ink">
          {activeProfile.isOwnerMode
            ? dm.share.activeSessions
            : formatMessage(dm.share.activeSessionsFor, { name: activeProfile.memberName ?? "" })}
        </h2>
        <div className="mt-4">
          {sessionsLoading && (
            <div className="flex flex-col gap-3">
              {Array.from({ length: 2 }).map((_, i) => (
                <Skeleton key={i} className="h-16" />
              ))}
            </div>
          )}
          {sessions && sessions.length === 0 ? (
            <EmptyState
              icon={QrCode}
              title={dm.share.noSessionsTitle}
              description={dm.share.noSessionsDescription}
            />
          ) : (
            <div className="flex flex-col gap-3">
              {sessions?.map((session) => (
                <div
                  key={session.id}
                  className="flex flex-col gap-2 rounded-xl border border-border bg-card p-4 sm:flex-row sm:items-center sm:justify-between"
                >
                  <div>
                    <p className="text-sm font-semibold text-ink">
                      {dm.share.scopes[session.scope as ShareScope] ?? session.scope}
                    </p>
                    <p className="text-xs text-ink-muted">
                      {formatMessage(dm.share.expires, { when: new Date(session.expires_at).toLocaleString() })}
                    </p>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleRevoke(session.id)}
                    className="flex items-center gap-1.5 self-start text-xs font-medium text-error hover:underline sm:self-auto"
                  >
                    <XCircle size={14} /> {dm.share.revoke}
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>

      <div className="mt-10">
        <h2 className="text-lg font-semibold text-ink">{dm.share.instructionsTitle}</h2>
        <p className="mt-1 text-sm text-ink-muted">{dm.share.instructionsDescription}</p>
        <div className="mt-4">
          {sessionsLoading && (
            <div className="flex flex-col gap-3">
              {Array.from({ length: 2 }).map((_, i) => (
                <Skeleton key={i} className="h-16" />
              ))}
            </div>
          )}
          {instructions && instructions.length === 0 ? (
            <EmptyState
              icon={EnvelopeSimple}
              title={dm.share.noInstructionsTitle}
              description={dm.share.noInstructionsDescription}
            />
          ) : (
            <div className="flex flex-col gap-3">
              {instructions?.map((instruction) => {
                const expanded = expandedInstructionId === instruction.id;
                return (
                  <div
                    key={instruction.id}
                    className="rounded-xl border border-border bg-card p-4"
                  >
                    <button
                      type="button"
                      onClick={() => handleToggleInstruction(instruction)}
                      className="flex w-full items-center justify-between gap-3 text-start"
                    >
                      <div className="flex items-center gap-2">
                        {!instruction.seen_at && (
                          <span className="h-2 w-2 shrink-0 rounded-full bg-primary" aria-label={dm.share.unread} />
                        )}
                        <div>
                          <p className="text-sm font-semibold text-ink">
                            {dm.share.doctorPrefix} {instruction.doctor_name} · {instruction.doctor_institution}
                          </p>
                          <p className="text-xs text-ink-muted">
                            {new Date(instruction.created_at).toLocaleString()}
                          </p>
                        </div>
                      </div>
                    </button>
                    {expanded && (
                      <p className="mt-3 whitespace-pre-wrap border-t border-border pt-3 text-sm text-ink">
                        {instruction.instructions}
                      </p>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
