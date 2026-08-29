"use client";

import { Suspense, useEffect, useRef, useState, type FormEvent } from "react";
import { useSearchParams } from "next/navigation";
import Image from "next/image";
import {
  PaperPlaneRight,
  Sparkle,
  Plus,
  Info,
  Paperclip,
  FileText,
  Warning,
  X,
  DotsThreeVertical,
  PushPin,
  PencilSimple,
  Trash,
  ClockCounterClockwise,
} from "@phosphor-icons/react/dist/ssr";
import { useAuth } from "@/lib/auth/AuthContext";
import { useActiveProfile } from "@/lib/family/ActiveProfileContext";
import { useAsyncResource } from "@/lib/hooks/useAsyncResource";
import { useCurrentIdentity } from "@/lib/hooks/useCurrentIdentity";
import { useConfirm } from "@/lib/dialog/ConfirmDialogProvider";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";
import {
  createChatSession,
  deleteChatSession,
  getChatMessages,
  listChatSessions,
  streamChatMessage,
  updateChatSession,
} from "@/lib/api/aiChat";
import { ChatMarkdown } from "@/components/dashboard/ChatMarkdown";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { Popover } from "@/components/ui/Popover";
import { AttachFromVaultModal } from "@/components/dashboard/AttachFromVaultModal";
import { HowToUseModal } from "@/components/dashboard/HowToUseModal";
import type { ChatMessage, ChatSession } from "@/lib/api/types";

/** Mirrors the backend's `GET /ai/sessions` ordering (is_pinned desc, updated_at desc) so
 * optimistic local updates (pin/unpin) re-sort the list without waiting on a refetch. */
function sortSessions(sessions: ChatSession[]): ChatSession[] {
  return [...sessions].sort((a, b) => {
    if (a.is_pinned !== b.is_pinned) return a.is_pinned ? -1 : 1;
    return new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime();
  });
}

function suggestedPrompts(dm: DashboardMessages): string[] {
  return [
    dm.assistant.suggestedPrompts.summarizeLatestLab,
    dm.assistant.suggestedPrompts.explainXray,
    dm.assistant.suggestedPrompts.explainMedications,
    dm.assistant.suggestedPrompts.anyConcerns,
  ];
}

function formatRelativeTime(dm: DashboardMessages, dateStr: string): string {
  const diffMs = Date.now() - new Date(dateStr).getTime();
  const diffMin = Math.round(diffMs / 60000);
  if (diffMin < 1) return dm.assistant.time.now;
  if (diffMin < 60) return formatMessage(dm.assistant.time.minutes, { value: diffMin });
  const diffHr = Math.round(diffMin / 60);
  if (diffHr < 24) return formatMessage(dm.assistant.time.hours, { value: diffHr });
  const diffDay = Math.round(diffHr / 24);
  if (diffDay < 7) return formatMessage(dm.assistant.time.days, { value: diffDay });
  const diffWeek = Math.round(diffDay / 7);
  if (diffWeek < 5) return formatMessage(dm.assistant.time.weeks, { value: diffWeek });
  const diffMonth = Math.round(diffDay / 30);
  if (diffMonth < 12) return formatMessage(dm.assistant.time.months, { value: diffMonth });
  return formatMessage(dm.assistant.time.years, { value: Math.round(diffDay / 365) });
}

/** The backend always appends AI_DISCLAIMER (be/app/services/prompts.py) as its own paragraph,
 * starting with "⚠️" - split it out so it can render as its own styled callout instead of
 * blending into the answer body. */
function splitAiNote(content: string): { body: string; note: string | null } {
  const lines = content.split("\n");
  const noteIndex = lines.findIndex((line) => line.trim().startsWith("⚠️"));
  if (noteIndex === -1) return { body: content, note: null };
  const note = lines[noteIndex].trim().replace(/^⚠️\s*/, "");
  const body = [...lines.slice(0, noteIndex), ...lines.slice(noteIndex + 1)].join("\n").trim();
  return { body, note };
}

/** Types out a session's title left-to-right the first time it arrives (i.e. when it flips
 * from null/"Untitled" to the backend's auto-generated title), instead of snapping in instantly.
 * Titles that are already set when this component first mounts render immediately - only the
 * null → titled transition animates. */
function SessionTitleText({ title, untitledLabel }: { title: string | null; untitledLabel: string }) {
  const [displayText, setDisplayText] = useState(title ?? untitledLabel);
  const prevTitleRef = useRef(title);
  const animatingRef = useRef(false);

  useEffect(() => {
    const prevTitle = prevTitleRef.current;
    prevTitleRef.current = title;

    if (title && !prevTitle && title !== displayText) {
      animatingRef.current = true;
      setDisplayText("");
      let i = 0;
      const intervalId = setInterval(() => {
        i += 1;
        setDisplayText(title.slice(0, i));
        if (i >= title.length) {
          clearInterval(intervalId);
          animatingRef.current = false;
        }
      }, 30);
      return () => clearInterval(intervalId);
    }

    if (!animatingRef.current) {
      setDisplayText(title ?? untitledLabel);
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [title]);

  return <span className="truncate">{displayText}</span>;
}

function AssistantContent() {
  const { getAccessToken } = useAuth();
  const searchParams = useSearchParams();
  const confirm = useConfirm();
  const { profile: activeProfile } = useActiveProfile();
  const identity = useCurrentIdentity();
  const dm = useDashboardMessages();
  // Each family member (and the owner) has their own chat history - never mix them. `undefined`
  // scopes to the account owner's own chats, matching the backend's `family_scope` default.
  const scopeId = activeProfile.isOwnerMode ? undefined : activeProfile.memberId ?? undefined;
  const {
    data: sessions,
    isLoading: sessionsLoading,
    refetch: refetchSessions,
    setData: setSessions,
  } = useAsyncResource((token) => listChatSessions(token, scopeId), [scopeId]);

  const [activeId, setActiveId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [streamingText, setStreamingText] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState("");
  const [attachedRecords, setAttachedRecords] = useState<{ id: string; title: string }[]>([]);
  const [attachModalOpen, setAttachModalOpen] = useState(false);
  const [howToUseOpen, setHowToUseOpen] = useState(false);
  const [menuOpenId, setMenuOpenId] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editValue, setEditValue] = useState("");
  // Past conversations live in a slide-in drawer on mobile (industry-standard pattern — see
  // ChatGPT/Claude mobile) instead of stacking below the chat; irrelevant above the `lg` grid
  // layout where the list is always visible in the sidebar column.
  const [historyOpen, setHistoryOpen] = useState(false);
  const menuTriggerRef = useRef<HTMLButtonElement>(null);
  const scrollRef = useRef<HTMLDivElement>(null);
  const initializedFromQuery = useRef(false);
  const skipNextHistoryFetch = useRef(false);
  // Guards the AI stream against the user switching conversations mid-response: aborts the
  // in-flight request and bumps requestSeqRef so any callbacks/results from it are ignored
  // rather than overwriting whatever conversation is now active.
  const streamAbortRef = useRef<AbortController | null>(null);
  const requestSeqRef = useRef(0);

  function interruptActiveStream() {
    streamAbortRef.current?.abort();
    streamAbortRef.current = null;
    requestSeqRef.current += 1;
    setIsStreaming(false);
    setStreamingText("");
  }

  useEffect(() => {
    return () => {
      streamAbortRef.current?.abort();
    };
  }, []);

  function removeAttachedRecord(id: string) {
    setAttachedRecords((prev) => prev.filter((r) => r.id !== id));
  }

  // Switching the active family member scopes chat to a different patient - start a fresh
  // view rather than leaving the previous member's conversation open (or attaching a new
  // message to the wrong person's session). Skipped on first mount so the initial load and
  // the `?conversation=` query-param restore below aren't immediately wiped out.
  const previousScopeId = useRef(scopeId);
  useEffect(() => {
    if (previousScopeId.current === scopeId) return;
    previousScopeId.current = scopeId;
    interruptActiveStream();
    setActiveId(null);
    setMessages([]);
    setAttachedRecords([]);
  }, [scopeId]);

  useEffect(() => {
    if (initializedFromQuery.current) return;
    initializedFromQuery.current = true;
    const fromQuery = searchParams.get("conversation");
    const prefill = searchParams.get("prefill");
    const recordId = searchParams.get("recordId");
    const recordTitle = searchParams.get("recordTitle");
    if (fromQuery) setActiveId(fromQuery);
    if (prefill) setInput(prefill);
    if (recordId) setAttachedRecords([{ id: recordId, title: recordTitle ?? dm.assistant.attachedDocument }]);
  }, [searchParams]);

  useEffect(() => {
    if (!activeId) {
      setMessages([]);
      return;
    }
    // Sessions created by handleSubmit already have their optimistic user message in state -
    // fetching history here would race the in-flight stream and briefly wipe the message out.
    if (skipNextHistoryFetch.current) {
      skipNextHistoryFetch.current = false;
      return;
    }
    let cancelled = false;
    (async () => {
      const token = await getAccessToken();
      if (!token || cancelled) return;
      try {
        const history = await getChatMessages(token, activeId);
        if (!cancelled) setMessages(history);
      } catch {
        // Ignore - session list still lets the user pick a different conversation.
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [activeId, getAccessToken]);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages.length, streamingText]);

  function startRename(session: ChatSession) {
    setMenuOpenId(null);
    setEditingId(session.id);
    setEditValue(session.title ?? "");
  }

  async function commitRename(session: ChatSession) {
    const nextTitle = editValue.trim();
    setEditingId(null);
    if (!nextTitle || nextTitle === (session.title ?? "")) return;
    try {
      const token = await getAccessToken();
      if (!token) return;
      const updated = await updateChatSession(token, session.id, { title: nextTitle });
      setSessions((prev) =>
        sortSessions((prev ?? []).map((s) => (s.id === session.id ? updated : s)))
      );
    } catch {
      // Leave the previous title in place - the list still reflects the last known-good state.
    }
  }

  async function togglePin(session: ChatSession) {
    setMenuOpenId(null);
    const nextPinned = !session.is_pinned;
    // Optimistic update so the list re-sorts immediately.
    setSessions((prev) =>
      sortSessions((prev ?? []).map((s) => (s.id === session.id ? { ...s, is_pinned: nextPinned } : s)))
    );
    try {
      const token = await getAccessToken();
      if (!token) return;
      const updated = await updateChatSession(token, session.id, { is_pinned: nextPinned });
      setSessions((prev) =>
        sortSessions((prev ?? []).map((s) => (s.id === session.id ? updated : s)))
      );
    } catch {
      // Revert on failure.
      setSessions((prev) =>
        sortSessions((prev ?? []).map((s) => (s.id === session.id ? { ...s, is_pinned: session.is_pinned } : s)))
      );
    }
  }

  async function handleDelete(session: ChatSession) {
    setMenuOpenId(null);
    const label = session.title?.trim() || dm.assistant.thisConversation;
    const confirmed = await confirm({
      title: formatMessage(dm.assistant.deleteConfirmTitle, { label }),
      description: dm.assistant.deleteConfirmDescription,
      confirmLabel: dm.common.delete,
      destructive: true,
    });
    if (!confirmed) return;
    try {
      const token = await getAccessToken();
      if (!token) return;
      await deleteChatSession(token, session.id);
      setSessions((prev) => (prev ?? []).filter((s) => s.id !== session.id));
      if (activeId === session.id) {
        interruptActiveStream();
        setActiveId(null);
        setAttachedRecords([]);
      }
    } catch {
      setError(dm.assistant.deleteError);
    }
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const text = input.trim();
    if (!text || isStreaming) return;

    setError("");
    setInput("");
    setIsStreaming(true);
    const sourceRecordIds = attachedRecords.map((r) => r.id);
    setAttachedRecords([]);

    const optimisticUserMessage: ChatMessage = {
      id: `pending-${Date.now()}`,
      session_id: activeId ?? "",
      role: "user",
      content: text,
      disclaimer_included: false,
      model_version: null,
      created_at: new Date().toISOString(),
      citations: [],
    };
    setMessages((prev) => [...prev, optimisticUserMessage]);
    setStreamingText("");

    // Starting a brand-new conversation - drop an "Untitled" placeholder into the sidebar right
    // away instead of waiting on createChatSession + refetchSessions, so the entry the user just
    // started appears instantly rather than popping in a beat later.
    const tempSessionId = activeId ? null : `pending-session-${Date.now()}`;
    if (tempSessionId) {
      const now = new Date().toISOString();
      setSessions((prev) => [
        {
          id: tempSessionId,
          family_member_id: scopeId ?? null,
          title: null,
          status: "active",
          total_messages: 0,
          is_pinned: false,
          created_at: now,
          updated_at: now,
        },
        ...(prev ?? []),
      ]);
    }

    streamAbortRef.current?.abort();
    const controller = new AbortController();
    streamAbortRef.current = controller;
    const mySeq = (requestSeqRef.current += 1);

    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);

      let sessionId = activeId;
      if (!sessionId) {
        const session = await createChatSession(token, scopeId);
        sessionId = session.id;
        skipNextHistoryFetch.current = true;
        setActiveId(sessionId);
        // Swap the placeholder for the real session (still untitled) rather than a full refetch,
        // so the sidebar entry doesn't flicker or briefly duplicate while the reply streams in.
        setSessions((prev) => sortSessions((prev ?? []).map((s) => (s.id === tempSessionId ? session : s))));
      }

      let fullText = "";
      await streamChatMessage(
        token,
        sessionId,
        text,
        sourceRecordIds.length ? sourceRecordIds : undefined,
        {
          onChunk: (chunk) => {
            if (requestSeqRef.current !== mySeq) return;
            fullText += chunk;
            setStreamingText(fullText);
          },
          onError: (message) => {
            if (requestSeqRef.current !== mySeq) return;
            setError(message);
          },
        },
        controller.signal
      );

      if (requestSeqRef.current !== mySeq) return;
      const finalHistory = await getChatMessages(token, sessionId);
      if (requestSeqRef.current !== mySeq) return;
      setMessages(finalHistory);
      setStreamingText("");
      // The backend auto-titles a session from the first exchange (see ai_chat.py) - refetch so
      // the sidebar picks up the generated title instead of showing "Untitled" forever.
      refetchSessions();
    } catch (err) {
      if (requestSeqRef.current !== mySeq) return; // superseded by a conversation switch - ignore
      if (err instanceof DOMException && err.name === "AbortError") return;
      setError(err instanceof Error ? err.message : dm.assistant.unavailable);
      setMessages((prev) => prev.filter((m) => m.id !== optimisticUserMessage.id));
      if (tempSessionId) setSessions((prev) => (prev ?? []).filter((s) => s.id !== tempSessionId));
    } finally {
      if (requestSeqRef.current === mySeq) setIsStreaming(false);
    }
  }

  const activeSession = (sessions ?? []).find((s) => s.id === activeId) ?? null;

  return (
    <div className="flex flex-col lg:min-h-0 lg:flex-1">
      {/* Inlined rather than using the shared PageHeading component, which stacks the action
          below the title on narrow screens - that left the info icon floating alone in empty
          space under the description on mobile. Keeping the row unconditional (no flex-col
          fallback) puts the icon directly next to the heading at every width, matching the
          desktop layout and the pattern used on the Family Management and Medications pages. */}
      <div className="mb-8 flex items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-ink sm:text-3xl">{dm.assistant.title}</h1>
          <p className="mt-1 text-sm text-ink-muted">{dm.assistant.description}</p>
        </div>
        <button
          type="button"
          onClick={() => setHowToUseOpen(true)}
          aria-label={dm.assistant.howToUseAria}
          title={dm.assistant.howToUseTitle}
          className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-ink-muted transition-colors hover:bg-primary-tint hover:text-primary"
        >
          <Info size={20} />
        </button>
      </div>

      <div className="grid grid-cols-1 gap-6 lg:min-h-0 lg:flex-1 lg:grid-cols-[260px_1fr] lg:grid-rows-1">
        {/* Mobile-only backdrop for the history drawer — has no effect at lg since the drawer
            is statically positioned there and historyOpen is never toggled true by desktop UI. */}
        {historyOpen && (
          <div
            className="fixed inset-0 z-40 bg-black/40 lg:hidden"
            onClick={() => setHistoryOpen(false)}
            aria-hidden="true"
          />
        )}

        <aside
          className={`fixed inset-y-0 start-0 z-50 flex w-[85vw] max-w-xs -translate-x-full flex-col overflow-y-auto bg-card p-4 shadow-xl transition-transform duration-300 ease-in-out rtl:translate-x-full lg:static lg:z-auto lg:order-1 lg:h-[calc(100vh_-_160px)] lg:w-auto lg:max-w-none lg:translate-x-0 lg:overflow-hidden lg:bg-transparent lg:p-0 lg:shadow-none lg:transition-none ${
            historyOpen ? "!translate-x-0" : ""
          }`}
        >
          <div className="mb-3 flex items-center justify-between lg:hidden">
            <h2 className="text-sm font-semibold text-ink">{dm.assistant.conversations}</h2>
            <button
              type="button"
              onClick={() => setHistoryOpen(false)}
              aria-label={dm.assistant.closeHistory}
              className="flex h-8 w-8 items-center justify-center rounded-full text-ink-muted hover:bg-primary-tint hover:text-primary"
            >
              <X size={18} />
            </button>
          </div>

          <button
            type="button"
            onClick={() => {
              interruptActiveStream();
              setActiveId(null);
              setAttachedRecords([]);
              setHistoryOpen(false);
            }}
            className="flex w-full items-center justify-center gap-2 rounded-full border border-primary px-4 py-2.5 text-sm font-semibold text-primary hover:bg-primary-tint"
          >
            <Plus size={16} weight="bold" /> {dm.assistant.newConversation}
          </button>
          <div className="lg:min-h-0 lg:flex-1 lg:overflow-y-auto">
          {sessionsLoading && (
            <div className="mt-4 flex flex-col gap-1">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-10" />
              ))}
            </div>
          )}

          <ul className="mt-4 flex flex-col gap-1">
            {!sessionsLoading && sortSessions(sessions ?? []).map((session) => (
              <li key={session.id} className="group relative">
                {editingId === session.id ? (
                  <input
                    autoFocus
                    value={editValue}
                    onChange={(e) => setEditValue(e.target.value)}
                    onBlur={() => commitRename(session)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") {
                        e.preventDefault();
                        commitRename(session);
                      } else if (e.key === "Escape") {
                        e.preventDefault();
                        setEditingId(null);
                      }
                    }}
                    className="w-full rounded-xl border border-primary bg-card px-3 py-2 text-sm font-medium text-ink outline-none focus:ring-2 focus:ring-primary/20"
                  />
                ) : (
                  <button
                    type="button"
                    onClick={() => {
                      setHistoryOpen(false);
                      if (session.id === activeId) return;
                      interruptActiveStream();
                      setActiveId(session.id);
                    }}
                    className={`flex w-full items-center justify-between gap-2 rounded-xl py-2.5 pl-3 pr-9 text-left text-sm font-medium ${
                      session.id === activeId ? "bg-primary-tint text-primary-dark" : "text-ink-muted hover:bg-card"
                    }`}
                  >
                    <span className="flex min-w-0 items-center gap-1.5">
                      {session.is_pinned && (
                        <PushPin size={12} weight="fill" className="shrink-0 text-primary" />
                      )}
                      <SessionTitleText title={session.title} untitledLabel={dm.assistant.untitled} />
                    </span>
                    <span className="shrink-0 text-[11px] font-normal text-ink-faint">
                      {formatRelativeTime(dm, session.updated_at)}
                    </span>
                  </button>
                )}

                {editingId !== session.id && (
                  <div className="absolute right-1 top-1/2 -translate-y-1/2">
                    <button
                      ref={menuOpenId === session.id ? menuTriggerRef : undefined}
                      type="button"
                      onClick={() => setMenuOpenId(menuOpenId === session.id ? null : session.id)}
                      aria-label={dm.assistant.conversationOptions}
                      className={`flex h-7 w-7 items-center justify-center rounded-full text-ink-faint hover:bg-card hover:text-ink max-lg:h-9 max-lg:w-9 max-lg:opacity-100 ${
                        menuOpenId === session.id ? "bg-card text-ink" : "opacity-0 group-hover:opacity-100 focus:opacity-100"
                      }`}
                    >
                      <DotsThreeVertical size={16} weight="bold" />
                    </button>
                  </div>
                )}
              </li>
            ))}
          </ul>
          </div>

          {(() => {
            const menuSession = (sessions ?? []).find((s) => s.id === menuOpenId);
            if (!menuSession) return null;
            return (
              <Popover
                open={menuOpenId !== null}
                onClose={() => setMenuOpenId(null)}
                triggerRef={menuTriggerRef}
                align="end"
                side="bottom"
                className="w-40 overflow-hidden py-1"
              >
                <button
                  type="button"
                  onClick={() => startRename(menuSession)}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-ink hover:bg-surface"
                >
                  <PencilSimple size={14} /> {dm.assistant.rename}
                </button>
                <button
                  type="button"
                  onClick={() => togglePin(menuSession)}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-ink hover:bg-surface"
                >
                  <PushPin size={14} weight={menuSession.is_pinned ? "fill" : "regular"} />
                  {menuSession.is_pinned ? dm.assistant.unpin : dm.assistant.pin}
                </button>
                <button
                  type="button"
                  onClick={() => handleDelete(menuSession)}
                  className="flex w-full items-center gap-2 px-3 py-2 text-left text-sm text-error hover:bg-surface"
                >
                  <Trash size={14} /> {dm.common.delete}
                </button>
              </Popover>
            );
          })()}
        </aside>

        <div className="order-1 flex h-[72vh] min-h-0 flex-col overflow-hidden rounded-2xl border border-border bg-card lg:order-2 lg:h-[calc(100vh_-_160px)]">
          {/* Mobile-only row with two distinct, clearly separated actions: History (neutral,
              opens the same conversation list the desktop sidebar shows) and New Conversation
              (primary-tinted, so it doesn't read as a second history-style control). Dividers
              on either side of the title keep the three zones visually distinct. Extra vertical
              padding here gives the tap targets more comfortable surrounding space. */}
          <div className="flex items-center justify-between gap-1 border-b border-border px-2 py-3.5 lg:hidden">
            <button
              type="button"
              onClick={() => setHistoryOpen(true)}
              aria-label={dm.assistant.openHistory}
              title={dm.assistant.openHistory}
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-ink-muted hover:bg-primary-tint hover:text-primary"
            >
              <ClockCounterClockwise size={20} />
            </button>
            <span className="min-w-0 flex-1 truncate border-x border-border px-3 text-center text-sm font-semibold text-ink">
              {activeSession?.title ?? dm.assistant.newConversation}
            </span>
            <button
              type="button"
              onClick={() => {
                interruptActiveStream();
                setActiveId(null);
                setAttachedRecords([]);
              }}
              aria-label={dm.assistant.startNewConversation}
              title={dm.assistant.startNewConversation}
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary-tint text-primary hover:bg-primary-tint/70"
            >
              <Plus size={18} weight="bold" />
            </button>
          </div>

          <div className="flex items-center gap-2 border-b border-border bg-primary-tint-subtle px-5 py-2.5 text-[12.5px] text-primary-dark">
            <Info size={15} className="shrink-0" />
            {dm.assistant.disclaimer}
          </div>

          <div ref={scrollRef} className="min-h-0 flex-1 space-y-[22px] overflow-y-auto px-5 py-8 lg:py-6">
            {messages.length === 0 && !streamingText && (
              <div className="flex h-full flex-col items-center justify-center gap-3.5 px-6 text-center">
                <span className="flex h-14 w-14 items-center justify-center rounded-full bg-primary-tint text-primary">
                  <Sparkle size={26} weight="fill" />
                </span>
                <h3 className="text-base font-semibold text-ink">{dm.assistant.emptyTitle}</h3>
                <p className="max-w-sm text-sm text-ink-muted">{dm.assistant.emptyDescription}</p>
                <div className="mt-1 flex w-full max-w-lg flex-col gap-2 sm:flex-row sm:flex-wrap sm:justify-center">
                  {suggestedPrompts(dm).map((prompt) => (
                    <button
                      key={prompt}
                      type="button"
                      onClick={() => setInput(prompt)}
                      className="w-full rounded-full border border-border bg-card px-3.5 py-2 text-center text-[13px] text-ink transition-colors hover:border-primary hover:bg-primary-tint-subtle hover:text-primary-dark sm:w-auto"
                    >
                      {prompt}
                    </button>
                  ))}
                </div>
              </div>
            )}

            {messages.map((message) => {
              const isUser = message.role === "user";
              const { body, note } = isUser ? { body: message.content, note: null } : splitAiNote(message.content);
              return (
                <div key={message.id} className={`flex gap-3 ${isUser ? "flex-row-reverse" : ""}`}>
                  {isUser ? (
                    <span className="flex h-8 w-8 shrink-0 items-center justify-center overflow-hidden rounded-full bg-primary text-xs font-bold text-primary-foreground">
                      {identity.photoUrl ? (
                        <Image
                          src={identity.photoUrl}
                          alt={identity.name}
                          width={32}
                          height={32}
                          className="h-full w-full object-cover"
                        />
                      ) : (
                        identity.initial
                      )}
                    </span>
                  ) : (
                    <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-tint text-primary">
                      <Sparkle size={16} weight="fill" />
                    </span>
                  )}
                  <div
                    className={`max-w-[640px] rounded-2xl px-[18px] py-3.5 text-[14.5px] leading-relaxed ${
                      isUser ? "rounded-tr bg-primary text-primary-foreground" : "rounded-tl bg-bubble-ai text-ink"
                    }`}
                  >
                    <ChatMarkdown content={body} />

                    {note && (
                      <div className="mt-3 flex items-start gap-2 rounded-lg bg-warning-bg px-3 py-2.5 text-xs leading-relaxed text-warning-dark">
                        <Warning size={14} weight="fill" className="mt-0.5 shrink-0" />
                        {note}
                      </div>
                    )}

                    {message.citations.length > 0 && (
                      <div className="mt-3.5 flex flex-wrap gap-2 border-t border-dashed border-border pt-3">
                        {message.citations.map((citation) => (
                          <span
                            key={citation.record_id}
                            className="flex items-center gap-1.5 rounded-full border border-border bg-card py-1 pl-1 pr-3 text-xs font-semibold text-primary-dark transition-colors hover:border-primary hover:bg-primary-tint-subtle"
                          >
                            <span className="flex h-4 w-4 items-center justify-center rounded bg-primary-tint text-primary">
                              <FileText size={10} weight="bold" />
                            </span>
                            {citation.title}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}

            {isStreaming && (
              <div className="flex gap-3">
                <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-tint text-primary">
                  <Sparkle size={16} weight="fill" />
                </span>
                <div className="max-w-[640px] rounded-2xl rounded-tl bg-bubble-ai px-[18px] py-3.5 text-[14.5px] leading-relaxed text-ink">
                  {streamingText ? (
                    <ChatMarkdown content={splitAiNote(streamingText).body} />
                  ) : (
                    <span className="flex items-center gap-1 py-1.5">
                      <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-primary [animation-delay:-0.3s]" />
                      <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-primary [animation-delay:-0.15s]" />
                      <span className="h-1.5 w-1.5 animate-bounce rounded-full bg-primary" />
                    </span>
                  )}
                </div>
              </div>
            )}
          </div>

          {error && <p className="px-5 pb-2 text-sm font-medium text-error">{error}</p>}

          <form onSubmit={handleSubmit} className="border-t border-border p-4">
            {attachedRecords.length > 0 && (
              <div className="mb-2 flex flex-wrap gap-2">
                {attachedRecords.map((record) => (
                  <span
                    key={record.id}
                    className="flex max-w-[220px] items-center gap-1.5 rounded-lg bg-primary-tint py-1 pl-2.5 pr-1.5 text-xs font-semibold text-primary-dark"
                  >
                    <Paperclip size={12} className="shrink-0" />
                    <span className="truncate">{record.title}</span>
                    <button
                      type="button"
                      onClick={() => removeAttachedRecord(record.id)}
                      aria-label={formatMessage(dm.assistant.removeAttachment, { title: record.title })}
                      className="shrink-0 text-primary-dark/70 hover:text-primary-dark"
                    >
                      <X size={12} />
                    </button>
                  </span>
                ))}
              </div>
            )}

            <div className="flex items-center gap-3">
              <input
                type="text"
                value={input}
                onChange={(e) => setInput(e.target.value)}
                placeholder={dm.assistant.inputPlaceholder}
                className="flex-1 rounded-full border border-border bg-card py-3 ps-4 pe-2 text-sm text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
              />

              <button
                type="button"
                onClick={() => setAttachModalOpen(true)}
                aria-label={dm.assistant.attachAria}
                className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-ink-muted transition-colors hover:bg-primary-tint hover:text-primary"
              >
                <Paperclip size={18} />
              </button>

              <button
                type="submit"
                disabled={!input.trim() || isStreaming}
                aria-label={dm.assistant.sendAria}
                className="flex h-11 w-11 shrink-0 items-center justify-center rounded-full bg-primary text-primary-foreground transition-colors hover:bg-primary-dark disabled:opacity-50"
              >
                <PaperPlaneRight size={18} weight="fill" />
              </button>
            </div>
          </form>
        </div>
      </div>

      <AttachFromVaultModal
        key={attachModalOpen ? "open" : "closed"}
        open={attachModalOpen}
        onClose={() => setAttachModalOpen(false)}
        scopeId={scopeId}
        onAttach={(records) => {
          setAttachedRecords((prev) => {
            const existingIds = new Set(prev.map((r) => r.id));
            return [...prev, ...records.filter((r) => !existingIds.has(r.id))];
          });
        }}
      />

      <HowToUseModal open={howToUseOpen} onClose={() => setHowToUseOpen(false)} />
    </div>
  );
}

export default function AssistantPage() {
  return (
    <Suspense fallback={null}>
      <AssistantContent />
    </Suspense>
  );
}
