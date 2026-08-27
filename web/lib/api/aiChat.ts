import { apiFetch, API_BASE_URL, ApiError } from "@/lib/api/client";
import type { ChatCitation, ChatMessage, ChatSession } from "@/lib/api/types";

export function listChatSessions(token: string, familyMemberId?: string) {
  return apiFetch<ChatSession[]>("/ai/sessions", { token, query: { family_member_id: familyMemberId } });
}

export function createChatSession(token: string, familyMemberId?: string) {
  return apiFetch<ChatSession>("/ai/sessions", {
    method: "POST",
    token,
    body: familyMemberId ? { family_member_id: familyMemberId } : {},
  });
}

export function getChatMessages(token: string, sessionId: string) {
  return apiFetch<ChatMessage[]>(`/ai/sessions/${sessionId}/messages`, { token });
}

export function deleteChatSession(token: string, sessionId: string) {
  return apiFetch<void>(`/ai/sessions/${sessionId}`, { method: "DELETE", token });
}

export function updateChatSession(
  token: string,
  sessionId: string,
  body: { title?: string; is_pinned?: boolean }
) {
  return apiFetch<ChatSession>(`/ai/sessions/${sessionId}`, { method: "PATCH", token, body });
}

interface StreamHandlers {
  onChunk: (text: string) => void;
  onCitations?: (citations: ChatCitation[]) => void;
  onError?: (message: string) => void;
}

/**
 * The backend streams via SSE on a POST endpoint, so the native EventSource API (GET-only)
 * can't be used - this reads the fetch body stream directly and parses `data: {...}\n\n` frames.
 */
export async function streamChatMessage(
  token: string,
  sessionId: string,
  content: string,
  sourceRecordIds: string[] | undefined,
  handlers: StreamHandlers,
  signal?: AbortSignal
): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/ai/sessions/${sessionId}/messages/stream`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      content,
      source_record_ids: sourceRecordIds?.length ? sourceRecordIds : undefined,
    }),
    signal,
  });

  if (!response.ok || !response.body) {
    const payload = await response.json().catch(() => null);
    throw new ApiError(response.status, payload?.detail, payload?.detail ?? "AI assistant is unavailable");
  }

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    buffer += decoder.decode(value, { stream: true });

    const frames = buffer.split("\n\n");
    buffer = frames.pop() ?? "";

    for (const frame of frames) {
      const line = frame.split("\n").find((l) => l.startsWith("data: "));
      if (!line) continue;
      const raw = line.slice("data: ".length);
      if (raw === "[DONE]") return;

      let event: { chunk?: string; citations?: ChatCitation[]; error?: string };
      try {
        event = JSON.parse(raw);
      } catch {
        // Skip a malformed/partial frame instead of aborting the whole stream over one bad chunk.
        continue;
      }
      if (event.chunk) handlers.onChunk(event.chunk);
      if (event.citations) handlers.onCitations?.(event.citations);
      if (event.error) handlers.onError?.(event.error);
    }
  }
}
