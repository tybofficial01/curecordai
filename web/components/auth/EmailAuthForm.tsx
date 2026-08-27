"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { ApiError } from "@/lib/api/client";
import { loginEmail, registerEmail, sendEmailOtp, verifyEmailOtp } from "@/lib/api/auth";
import { useAuth } from "@/lib/auth/AuthContext";
import { PasswordInput } from "@/components/auth/PasswordInput";
import { PENDING_NAME_KEY } from "@/lib/onboarding/OnboardingContext";
import { formatMessage, useDashboardMessages, type DashboardMessages } from "@/lib/locale/dashboardMessages";

type SignupStep = "details" | "otp";

function passwordIssue(password: string, errors: DashboardMessages["auth"]["errors"]): string | null {
  if (password.length < 8) return errors.passwordTooShort;
  if (!/[A-Z]/.test(password)) return errors.passwordNeedsUppercase;
  if (!/\d/.test(password)) return errors.passwordNeedsDigit;
  return null;
}

export function EmailSignInForm() {
  const router = useRouter();
  const { applySession, refreshUser } = useAuth();
  const dm = useDashboardMessages();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (!email.trim() || !password) {
      setError(dm.auth.errors.enterEmailAndPassword);
      return;
    }
    setSubmitting(true);
    try {
      const result = await loginEmail(email.trim(), password);
      applySession(result);
      await refreshUser();
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.errors.signInFailed);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4" noValidate>
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
      <div>
        <div className="flex items-center justify-between">
          <label htmlFor="password" className="block text-sm font-medium text-ink">
            {dm.auth.passwordLabel}
          </label>
          <Link href="/auth/forgot-password" className="text-xs font-medium text-primary hover:underline">
            {dm.auth.forgotPassword}
          </Link>
        </div>
        <PasswordInput id="password" value={password} onChange={setPassword} autoComplete="current-password" />
      </div>
      {error && <p className="text-sm font-medium text-error">{error}</p>}
      <button
        type="submit"
        disabled={submitting}
        className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
      >
        {submitting ? dm.auth.signingIn : dm.auth.signIn}
      </button>
    </form>
  );
}

export function EmailSignUpForm() {
  const router = useRouter();
  const { applySession, refreshUser } = useAuth();
  const dm = useDashboardMessages();
  const [step, setStep] = useState<SignupStep>("details");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [fullName, setFullName] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmitDetails(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (fullName.trim().length < 2) {
      setError(dm.auth.errors.enterFullName);
      return;
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      setError(dm.auth.errors.invalidEmail);
      return;
    }
    const issue = passwordIssue(password, dm.auth.errors);
    if (issue) {
      setError(issue);
      return;
    }
    if (password !== confirmPassword) {
      setError(dm.auth.errors.passwordsDoNotMatch);
      return;
    }
    setSubmitting(true);
    try {
      await sendEmailOtp(email.trim());
      setStep("otp");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.errors.couldNotSendCode);
    } finally {
      setSubmitting(false);
    }
  }

  async function handleVerifyOtp(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (!/^\d{6}$/.test(otp)) {
      setError(dm.auth.errors.otpInvalid);
      return;
    }
    setSubmitting(true);
    try {
      const verifyResult = await verifyEmailOtp(email.trim(), otp);
      const result = await registerEmail(
        email.trim(),
        password,
        fullName.trim(),
        verifyResult.email_verified_token
      );
      applySession(result);
      await refreshUser();
      if (typeof window !== "undefined") {
        window.sessionStorage.setItem(PENDING_NAME_KEY, fullName.trim());
      }
      router.push("/auth/onboarding/step1");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.errors.codeMismatch);
    } finally {
      setSubmitting(false);
    }
  }

  if (step === "otp") {
    return (
      <form onSubmit={handleVerifyOtp} className="flex flex-col gap-4" noValidate>
        <div>
          <label htmlFor="otp" className="block text-sm font-medium text-ink">
            {formatMessage(dm.auth.otpLabelEmail, { target: email })}
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
        {error && <p className="text-sm font-medium text-error">{error}</p>}
        <button
          type="submit"
          disabled={submitting}
          className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
        >
          {submitting ? dm.auth.verifying : dm.auth.verifyCode}
        </button>
        <button
          type="button"
          onClick={() => {
            setStep("details");
            setOtp("");
            setError("");
          }}
          className="text-sm font-medium text-ink-muted hover:text-primary"
        >
          {dm.auth.editDetails}
        </button>
      </form>
    );
  }

  return (
    <form onSubmit={handleSubmitDetails} className="flex flex-col gap-4" noValidate>
      <div>
        <label htmlFor="fullName" className="block text-sm font-medium text-ink">
          {dm.auth.fullNameLabel}
        </label>
        <input
          id="fullName"
          type="text"
          autoComplete="name"
          value={fullName}
          onChange={(e) => setFullName(e.target.value)}
          className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
        />
      </div>
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
      <div>
        <label htmlFor="password" className="block text-sm font-medium text-ink">
          {dm.auth.createPasswordLabel}
        </label>
        <PasswordInput id="password" value={password} onChange={setPassword} autoComplete="new-password" />
        <p className="mt-1.5 text-xs text-ink-muted">
          {dm.auth.passwordHint}
        </p>
      </div>
      <div>
        <label htmlFor="confirmPassword" className="block text-sm font-medium text-ink">
          {dm.auth.confirmPasswordLabel}
        </label>
        <PasswordInput
          id="confirmPassword"
          value={confirmPassword}
          onChange={setConfirmPassword}
          autoComplete="new-password"
        />
      </div>
      {error && <p className="text-sm font-medium text-error">{error}</p>}
      <button
        type="submit"
        disabled={submitting}
        className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
      >
        {submitting ? dm.auth.sendingCode : dm.auth.continueWithEmail}
      </button>
    </form>
  );
}
