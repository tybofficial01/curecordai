"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { ApiError } from "@/lib/api/client";
import { registerPhone, sendPhoneOtp, verifyPhoneOtp } from "@/lib/api/auth";
import { useAuth } from "@/lib/auth/AuthContext";
import { CountryCodeSelect } from "@/components/auth/CountryCodeSelect";
import { DEFAULT_COUNTRY, type Country } from "@/lib/countries";
import { PENDING_NAME_KEY } from "@/lib/onboarding/OnboardingContext";
import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";

type Step = "phone" | "details" | "otp" | "name";

export function PhoneAuthForm({ mode }: { mode: "signin" | "signup" }) {
  const router = useRouter();
  const { applySession, refreshUser } = useAuth();
  const dm = useDashboardMessages();
  const purpose = mode === "signin" ? "login" : "registration";

  const [step, setStep] = useState<Step>(mode === "signup" ? "details" : "phone");
  const [country, setCountry] = useState<Country>(DEFAULT_COUNTRY);
  const [localNumber, setLocalNumber] = useState("");
  // The E.164 string the backend validates/sends OTPs to - same format as before,
  // just assembled from the flag selector + local number instead of one free-text field.
  const phone = `${country.dialCode}${localNumber}`;
  const [otp, setOtp] = useState("");
  const [fullName, setFullName] = useState("");
  const [otpVerifiedToken, setOtpVerifiedToken] = useState("");
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  async function completeSignIn() {
    await refreshUser();
    router.push("/dashboard");
  }

  async function completeSignUp() {
    await refreshUser();
    if (typeof window !== "undefined") {
      window.sessionStorage.setItem(PENDING_NAME_KEY, fullName.trim());
    }
    router.push("/auth/onboarding/step1");
  }

  async function handleSubmitDetails(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (fullName.trim().length < 2) {
      setError(dm.auth.errors.enterFullName);
      return;
    }
    if (!/^\+[1-9]\d{6,14}$/.test(phone)) {
      setError(dm.auth.errors.invalidPhone);
      return;
    }
    setSubmitting(true);
    try {
      await sendPhoneOtp(phone, purpose);
      setStep("otp");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.errors.couldNotSendCode);
    } finally {
      setSubmitting(false);
    }
  }

  async function handleSendOtp(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (!/^\+[1-9]\d{6,14}$/.test(phone)) {
      setError(dm.auth.errors.invalidPhone);
      return;
    }
    setSubmitting(true);
    try {
      await sendPhoneOtp(phone, purpose);
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
      setError(dm.auth.errors.otpInvalidSent);
      return;
    }
    setSubmitting(true);
    try {
      const result = await verifyPhoneOtp(phone, otp, purpose);
      if (result.is_new_user && result.otp_verified_token) {
        if (mode === "signup" && fullName.trim().length >= 2) {
          // Full name was already collected up front - finish registration immediately.
          const registered = await registerPhone(fullName.trim(), result.otp_verified_token);
          applySession(registered);
          await completeSignUp();
          return;
        }
        setOtpVerifiedToken(result.otp_verified_token);
        setStep("name");
        return;
      }
      // Existing user - verify already returned a session (covers login, and a "sign up" attempt
      // on an already-registered number, which the backend treats as a login).
      applySession(result);
      await completeSignIn();
    } catch (err) {
      setError(
        err instanceof ApiError
          ? err.message
          : dm.auth.errors.couldNotVerifyCode
      );
    } finally {
      setSubmitting(false);
    }
  }

  async function handleCompleteRegistration(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    if (fullName.trim().length < 2) {
      setError(dm.auth.errors.enterFullNameToFinish);
      return;
    }
    setSubmitting(true);
    try {
      const result = await registerPhone(fullName.trim(), otpVerifiedToken);
      applySession(result);
      if (mode === "signup") {
        await completeSignUp();
      } else {
        await completeSignIn();
      }
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.errors.registrationFailed);
    } finally {
      setSubmitting(false);
    }
  }

  if (step === "otp") {
    return (
      <form onSubmit={handleVerifyOtp} className="flex flex-col gap-4" noValidate>
        <div>
          <label htmlFor="otp" className="block text-sm font-medium text-ink">
            {formatMessage(dm.auth.otpLabelPhone, { target: phone })}
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
            setStep(mode === "signup" ? "details" : "phone");
            setOtp("");
            setLocalNumber("");
            setError("");
          }}
          className="text-sm font-medium text-ink-muted hover:text-primary"
        >
          {dm.auth.useDifferentNumber}
        </button>
      </form>
    );
  }

  if (step === "details") {
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
          <label htmlFor="phone" className="block text-sm font-medium text-ink">
            {dm.auth.phoneLabel}
          </label>
          <div className="mt-1.5 flex">
            <CountryCodeSelect value={country} onChange={setCountry} />
            <input
              id="phone"
              type="tel"
              inputMode="numeric"
              autoComplete="tel-national"
              placeholder={dm.auth.phonePlaceholder}
              value={localNumber}
              onChange={(e) => setLocalNumber(e.target.value.replace(/[^\d]/g, ""))}
              className="w-full min-w-0 flex-1 rounded-e-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:z-10 focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
          </div>
          <p className="mt-1.5 text-xs text-ink-muted">{dm.auth.phoneHint}</p>
        </div>
        {error && <p className="text-sm font-medium text-error">{error}</p>}
        <button
          type="submit"
          disabled={submitting}
          className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
        >
          {submitting ? dm.auth.sendingCode : dm.auth.sendVerificationCode}
        </button>
      </form>
    );
  }

  if (step === "name") {
    return (
      <form onSubmit={handleCompleteRegistration} className="flex flex-col gap-4" noValidate>
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
        {error && <p className="text-sm font-medium text-error">{error}</p>}
        <button
          type="submit"
          disabled={submitting}
          className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
        >
          {submitting ? dm.auth.creatingAccount : dm.auth.completeSignUp}
        </button>
      </form>
    );
  }

  return (
    <form onSubmit={handleSendOtp} className="flex flex-col gap-4" noValidate>
      <div>
        <label htmlFor="phone" className="block text-sm font-medium text-ink">
          {dm.auth.phoneLabel}
        </label>
        <div className="mt-1.5 flex">
          <CountryCodeSelect value={country} onChange={setCountry} />
          <input
            id="phone"
            type="tel"
            inputMode="numeric"
            autoComplete="tel-national"
            placeholder={dm.auth.phonePlaceholder}
            value={localNumber}
            onChange={(e) => setLocalNumber(e.target.value.replace(/[^\d]/g, ""))}
            className="w-full min-w-0 flex-1 rounded-r-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:z-10 focus:border-primary focus:ring-2 focus:ring-primary/20"
          />
        </div>
        <p className="mt-1.5 text-xs text-ink-muted">{dm.auth.phoneHint}</p>
      </div>
      {error && <p className="text-sm font-medium text-error">{error}</p>}
      <button
        type="submit"
        disabled={submitting}
        className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70"
      >
        {submitting ? dm.auth.sendingCode : dm.auth.sendVerificationCode}
      </button>
    </form>
  );
}
