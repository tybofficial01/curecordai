import { NextResponse, type NextRequest } from "next/server";
import { BACKEND_URL, REFRESH_COOKIE, clearRefreshCookie, setRefreshCookie } from "@/lib/api/authProxy";

export async function POST(request: NextRequest) {
  const refreshToken = request.cookies.get(REFRESH_COOKIE)?.value;
  if (!refreshToken) {
    return NextResponse.json({ detail: "No active session" }, { status: 401 });
  }

  const backendResponse = await fetch(`${BACKEND_URL}/auth/token/refresh`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ refresh_token: refreshToken }),
  });

  const payload = await backendResponse.json().catch(() => null);

  if (!backendResponse.ok) {
    const failed = NextResponse.json(payload ?? { detail: "Session expired" }, {
      status: backendResponse.status,
    });
    clearRefreshCookie(failed);
    return failed;
  }

  const { refresh_token, ...rest } = payload ?? {};
  const response = NextResponse.json(rest, { status: 200 });
  if (refresh_token) setRefreshCookie(response, refresh_token);
  return response;
}
