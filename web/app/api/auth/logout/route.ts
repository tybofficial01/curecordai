import { NextResponse, type NextRequest } from "next/server";
import { BACKEND_URL, REFRESH_COOKIE, clearRefreshCookie } from "@/lib/api/authProxy";

export async function POST(request: NextRequest) {
  const refreshToken = request.cookies.get(REFRESH_COOKIE)?.value;
  const body = await request.json().catch(() => ({}));

  // The backend's /auth/logout requires a currently-valid access token to identify the session
  // to revoke. The client's in-memory access token may already be expired (e.g. an idle tab) -
  // in that case /auth/logout would 401 before ever revoking the refresh token, leaving it valid
  // server-side for up to 30 days while the client believes it's fully signed out. Since a
  // refresh token this route can read is itself proof of a live session, always mint a fresh
  // access token from it first so revocation actually happens.
  if (refreshToken) {
    try {
      const refreshResponse = await fetch(`${BACKEND_URL}/auth/token/refresh`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: refreshToken }),
      });
      const refreshed = await refreshResponse.json().catch(() => null);

      if (refreshResponse.ok && refreshed?.access_token) {
        await fetch(`${BACKEND_URL}/auth/logout`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${refreshed.access_token}`,
          },
          body: JSON.stringify({
            refresh_token: refreshed.refresh_token ?? refreshToken,
            all_devices: Boolean(body?.all_devices),
          }),
        }).catch(() => null);
      }
    } catch {
      // best-effort - the cookie is cleared regardless, so the client always ends up signed out
    }
  }

  const response = NextResponse.json({ ok: true });
  clearRefreshCookie(response);
  return response;
}
