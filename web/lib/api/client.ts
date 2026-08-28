function resolveApiBaseUrl(): string {
  if (process.env.NEXT_PUBLIC_API_BASE_URL) return process.env.NEXT_PUBLIC_API_BASE_URL;
  if (process.env.NODE_ENV === "production") {
    throw new Error("NEXT_PUBLIC_API_BASE_URL is not set - configure it in the Vercel project settings.");
  }
  return "http://localhost:8000/api/v1";
}

export const API_BASE_URL = resolveApiBaseUrl();

export class ApiError extends Error {
  status: number;
  detail: unknown;

  constructor(status: number, detail: unknown, message?: string) {
    super(message ?? (typeof detail === "string" ? detail : `Request failed (${status})`));
    this.status = status;
    this.detail = detail;
    this.name = "ApiError";
  }
}

/**
 * Pulls a readable message out of a FastAPI-style error payload: `{"detail": "..."}`,
 * a Pydantic 422 validation array (`{"detail": [{"msg": "..."}]}`), or slowapi's rate-limit
 * shape (`{"error": "..."}`, no `detail` key at all).
 */
function extractErrorMessage(detail: unknown, fallback: string): string {
  if (typeof detail === "string") return detail;
  if (Array.isArray(detail)) {
    const first = detail[0];
    if (first && typeof first === "object" && "msg" in first) return String(first.msg);
  }
  if (detail && typeof detail === "object" && "error" in detail && typeof (detail as { error: unknown }).error === "string") {
    return (detail as { error: string }).error;
  }
  return fallback;
}

/** Builds an ApiError from a parsed JSON error body - shared by apiFetch and the auth proxy callers. */
export function errorFromPayload(status: number, payload: unknown, fallback: string): ApiError {
  const detail = payload && typeof payload === "object" && "detail" in payload ? (payload as { detail: unknown }).detail : payload;
  return new ApiError(status, detail, extractErrorMessage(detail, fallback));
}

interface RequestOptions {
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE";
  body?: unknown;
  token?: string | null;
  query?: Record<string, string | number | boolean | undefined | null>;
  signal?: AbortSignal;
}

function buildUrl(path: string, query?: RequestOptions["query"]): string {
  const url = new URL(`${API_BASE_URL}${path}`);
  if (query) {
    for (const [key, value] of Object.entries(query)) {
      if (value !== undefined && value !== null && value !== "") {
        url.searchParams.set(key, String(value));
      }
    }
  }
  return url.toString();
}

export async function apiFetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
  const { method = "GET", body, token, query, signal } = options;

  const headers: Record<string, string> = {};
  if (body !== undefined) headers["Content-Type"] = "application/json";
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const response = await fetch(buildUrl(path, query), {
    method,
    headers,
    body: body !== undefined ? JSON.stringify(body) : undefined,
    signal,
  });

  if (response.status === 204) {
    return undefined as T;
  }

  const isJson = response.headers.get("content-type")?.includes("application/json");
  const payload = isJson ? await response.json().catch(() => null) : null;

  if (!response.ok) {
    throw errorFromPayload(response.status, payload, response.statusText);
  }

  return payload as T;
}
