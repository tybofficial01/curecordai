import type { NextRequest } from "next/server";
import { proxyTokenIssuingRequest } from "@/lib/api/authProxy";

export async function POST(request: NextRequest) {
  const body = await request.json();
  return proxyTokenIssuingRequest("/auth/oauth/apple", body);
}
