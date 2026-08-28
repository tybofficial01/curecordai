"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ApiError } from "@/lib/api/client";
import { requestPasswordReset, resetPassword } from "@/lib/api/auth";
import { useAuth } from "@/lib/auth/AuthContext";
import { PasswordInput } from "@/components/auth/PasswordInput";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";

type Step = "email" | "reset";

function passwordIssue(password: string, errors: DashboardMessages["auth"]["errors"]): string | null {
  if (password.length < 8) return errors.passwordTooShort;
  if (!/[A-Z]/.test(password)) return errors.passwordNeedsUppercase;
  if (!/\d/.test(password)) return errors.passwordNeedsDigit;
  return null;
}

export function ForgotPasswordForm() {
  const router = useRouter();
  const { applySession, refreshUser } = useAuth();
  const dm = useDashboardMessages();
  const [step, setStep] = useState<Step>("email");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleRequestCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError(dm.auth.errors.invalidEmail);
      return;
    }
    setError("");
    setSubmitting(true);
    try {
      await requestPasswordReset(email.trim());
      setStep("reset");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.forgot.couldNotSend);
    } finally {
      setSubmitting(false);
    }
  }

  async function handleReset(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!/^\d{6}$/.test(otp)) {
      setError(dm.auth.errors.otpInvalid);
      return;
    }
    const issue = passwordIssue(newPassword, dm.auth.errors);
    if (issue) {
      setError(issue);
      return;
    }
    setError("");
    setSubmitting(true);
    try {
      const result = await resetPassword(email.trim(), otp, newPassword);
      applySession(result);
      await refreshUser();
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.forgot.codeFailed);
    } finally {
      setSubmitting(false);
    }
  }

  if (step === "reset") {
    return (
      <>
        <h1 className="text-2xl font-bold text-ink">{dm.auth.forgot.resetTitle}</h1>
        <p className="mt-1 text-sm text-ink-muted">
          {formatMessage(dm.auth.forgot.resetDescription, { email })}
        </p>
        <form onSubmit={handleReset} className="mt-6 flex flex-col gap-4" noValidate>
          <div>
            <label htmlFor="otp" className="block text-sm font-medium text-ink">
              {dm.auth.forgot.verificationCode}
            </label>
            <input
              id="otp"
              type="text"
              inputMode="numeric"
              maxLength={6}
              autoComplete="one-time-code"
              value={otp}
              onChange={(e) => setOtp(e.target.value.replace(/\D/g, ""))}
              className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-center text-lg tracking-[0.5em] text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
          </div>
          <div>
            <label htmlFor="newPassword" className="block text-sm font-medium text-ink">
              {dm.auth.forgot.newPassword}
            </label>
            <PasswordInput id="newPassword" value={newPassword} onChange={setNewPassword} autoComplete="new-password" />
            <p className="mt-1.5 text-xs text-ink-muted">
              {dm.auth.passwordHint}
            </p>
          </div>
          {error && <p className="text-sm font-medium text-error">{error}</p>}
          <button
            type="submit"
            disabled={submitting}
            className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
          >
            {submitting ? dm.auth.forgot.resetting : dm.auth.forgot.resetPassword}
          </button>
          <button
            type="button"
            onClick={() => {
              setStep("email");
              setOtp("");
              setNewPassword("");
              setError("");
            }}
            className="text-sm font-medium text-ink-muted hover:text-primary"
          >
            {dm.auth.useDifferentEmail}
          </button>
        </form>
      </>
    );
  }

  return (
    <>
      <h1 className="text-2xl font-bold text-ink">{dm.auth.forgot.title}</h1>
      <p className="mt-1 text-sm text-ink-muted">
        {dm.auth.forgot.description}
      </p>
      <form onSubmit={handleRequestCode} className="mt-6 flex flex-col gap-4" noValidate>
        <div>
          <label htmlFor="email" className="block text-sm font-medium text-ink">
            {dm.auth.emailLabel}
          </label>
          <input
            id="email"
            type="email"
            autoComplete="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
          />
        </div>
        {error && <p className="text-sm font-medium text-error">{error}</p>}
        <button
          type="submit"
          disabled={submitting}
          className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
        >
          {submitting ? dm.auth.sendingCode : dm.auth.forgot.sendResetCode}
        </button>
      </form>
      <p className="mt-8 text-center text-sm text-ink-muted">
        {dm.auth.forgot.rememberedIt}{" "}
        <Link href="/auth/signin" className="font-medium text-primary hover:underline">
          {dm.auth.signIn}
        </Link>
      </p>
    </>
  );
}
