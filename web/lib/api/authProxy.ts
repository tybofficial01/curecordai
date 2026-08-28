import { NextResponse } from "next/server";

function resolveBackendUrl(): string {
  if (process.env.BACKEND_INTERNAL_URL) return process.env.BACKEND_INTERNAL_URL;
  if (process.env.NODE_ENV === "production") {
    throw new Error("BACKEND_INTERNAL_URL is not set - configure it in the Vercel project settings.");
  }
  return "http://localhost:8000/api/v1";
}

const BACKEND_URL = resolveBackendUrl();
const REFRESH_COOKIE = "curecord_rt";

interface BackendTokenPayload {
  user?: unknown;
  access_token?: string;
  refresh_token?: string;
  token_type?: string;
  expires_at?: string;
  [key: string]: unknown;
}

/**
 * Forwards a token-issuing auth request to the backend, then strips the long-lived refresh
 * token out of the JSON body entirely - it only ever leaves this server as an httpOnly cookie,
 * so it's never reachable from browser JS (the real XSS blast radius here, unlike the 15-minute
 * access token which is fine to hand back in the response body).
 */
export async function proxyTokenIssuingRequest(
  backendPath: string,
  body: unknown
): Promise<NextResponse> {
  const backendResponse = await fetch(`${BACKEND_URL}${backendPath}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body ?? {}),
  });

  const payload = (await backendResponse.json().catch(() => null)) as BackendTokenPayload | null;

  if (!backendResponse.ok) {
    return NextResponse.json(payload ?? { detail: "Request failed" }, {
      status: backendResponse.status,
    });
  }

  const { refresh_token, ...rest } = payload ?? {};
  const response = NextResponse.json(rest, { status: backendResponse.status });

  if (refresh_token) {
    setRefreshCookie(response, refresh_token);
  }

  return response;
}

export function setRefreshCookie(response: NextResponse, refreshToken: string): void {
  response.cookies.set(REFRESH_COOKIE, refreshToken, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/api/auth",
    maxAge: 60 * 60 * 24 * 30, // 30 days - matches JWT_REFRESH_TOKEN_EXPIRE_DAYS
  });
}

export function clearRefreshCookie(response: NextResponse): void {
  response.cookies.set(REFRESH_COOKIE, "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/api/auth",
    maxAge: 0,
  });
}

export { BACKEND_URL, REFRESH_COOKIE };
