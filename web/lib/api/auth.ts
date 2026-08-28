import { apiFetch, errorFromPayload } from "@/lib/api/client";
import type { AuthUser, EmailOtpVerifyResponse, OtpSendResponse } from "@/lib/api/types";

export interface TokenIssuedPayload {
  user?: AuthUser;
  access_token?: string;
  token_type?: string;
  expires_at?: string;
  is_new_user?: boolean;
}

export interface OtpVerifyPayload extends TokenIssuedPayload {
  verified: boolean;
  is_new_user: boolean;
  otp_verified_token?: string;
}

async function proxyPost<T>(path: string, body: unknown): Promise<T> {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body ?? {}),
    credentials: "same-origin",
  });
  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    throw errorFromPayload(response.status, payload, "Request failed");
  }
  return payload as T;
}

// ── Phone OTP ─────────────────────────────────────────────────────────────────

export function sendPhoneOtp(phoneNumber: string, purpose: "registration" | "login") {
  return apiFetch<OtpSendResponse>("/auth/otp/send", {
    method: "POST",
    body: { phone_number: phoneNumber, purpose },
  });
}

export function verifyPhoneOtp(phoneNumber: string, otp: string, purpose: "registration" | "login") {
  return proxyPost<OtpVerifyPayload>("/api/auth/otp-verify", {
    phone_number: phoneNumber,
    otp,
    purpose,
  });
}

export function registerPhone(fullName: string, otpVerifiedToken: string) {
  return proxyPost<TokenIssuedPayload>("/api/auth/register-phone", {
    full_name: fullName,
    otp_verified_token: otpVerifiedToken,
  });
}

// ── Email + Password ────────────────────────────────────────────────────────

export function sendEmailOtp(email: string) {
  return apiFetch<OtpSendResponse>("/auth/otp/send-email", {
    method: "POST",
    body: { email },
  });
}

export function verifyEmailOtp(email: string, otp: string) {
  return apiFetch<EmailOtpVerifyResponse>("/auth/otp/verify-email", {
    method: "POST",
    body: { email, otp },
  });
}

export function registerEmail(
  email: string,
  password: string,
  fullName: string,
  emailVerifiedToken: string
) {
  return proxyPost<TokenIssuedPayload>("/api/auth/register-email", {
    email,
    password,
    full_name: fullName,
    email_verified_token: emailVerifiedToken,
  });
}

export function loginEmail(email: string, password: string) {
  return proxyPost<TokenIssuedPayload>("/api/auth/login-email", { email, password });
}

export function requestPasswordReset(email: string) {
  return apiFetch<OtpSendResponse>("/auth/password/forgot", {
    method: "POST",
    body: { email },
  });
}

export function resetPassword(email: string, otp: string, newPassword: string) {
  return proxyPost<TokenIssuedPayload>("/api/auth/reset-password", {
    email,
    otp,
    new_password: newPassword,
  });
}

// ── OAuth ─────────────────────────────────────────────────────────────────────

export function loginGoogle(idToken: string) {
  return proxyPost<TokenIssuedPayload>("/api/auth/oauth-google", { id_token: idToken });
}

export function loginApple(identityToken: string, fullName?: string) {
  return proxyPost<TokenIssuedPayload>("/api/auth/oauth-apple", {
    identity_token: identityToken,
    full_name: fullName,
  });
}
