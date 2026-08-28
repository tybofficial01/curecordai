"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { OnboardingProgress } from "@/components/onboarding/OnboardingProgress";
import { GENDER_OPTIONS, useOnboarding } from "@/lib/onboarding/OnboardingContext";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

const CURRENT_YEAR = new Date().getFullYear();

export default function OnboardingStep1Page() {
  const router = useRouter();
  const { step1, setStep1 } = useOnboarding();
  const dm = useDashboardMessages();
  const [fullName, setFullName] = useState(step1.fullName);
  const [yearOfBirth, setYearOfBirth] = useState(step1.yearOfBirth);
  const [gender, setGender] = useState(step1.gender);
  const [error, setError] = useState("");

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");

    if (fullName.trim().length < 2) {
      setError(dm.auth.errors.enterFullName);
      return;
    }
    const year = Number(yearOfBirth);
    if (!/^\d{4}$/.test(yearOfBirth) || year < 1900 || year > CURRENT_YEAR || CURRENT_YEAR - year < 13) {
      setError(dm.auth.onboarding.invalidYear);
      return;
    }
    if (!gender) {
      setError(dm.auth.onboarding.selectGender);
      return;
    }

    setStep1({ fullName: fullName.trim(), yearOfBirth, gender });
    router.push("/auth/onboarding/step2");
  }

  return (
    <>
      <OnboardingProgress step={1} />
      <h1 className="text-2xl font-bold text-ink">{dm.auth.onboarding.step1Title}</h1>
      <p className="mt-1 text-sm text-ink-muted">{dm.auth.onboarding.step1Description}</p>

      <form onSubmit={handleSubmit} className="mt-6 flex flex-col gap-4" noValidate>
        <div>
          <label htmlFor="fullName" className="block text-sm font-medium text-ink">
            {dm.auth.onboarding.fullName}
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
          <label htmlFor="yearOfBirth" className="block text-sm font-medium text-ink">
            {dm.auth.onboarding.yearOfBirth}
          </label>
          <input
            id="yearOfBirth"
            type="text"
            inputMode="numeric"
            maxLength={4}
            placeholder="1990"
            value={yearOfBirth}
            onChange={(e) => setYearOfBirth(e.target.value.replace(/\D/g, ""))}
            className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
          />
        </div>
        <div>
          <span className="block text-sm font-medium text-ink">{dm.auth.onboarding.gender}</span>
          <div className="mt-1.5 grid grid-cols-2 gap-2 sm:grid-cols-4">
            {GENDER_OPTIONS.map((option) => (
              <button
                key={option.value}
                type="button"
                onClick={() => setGender(option.value)}
                className={`rounded-xl border px-3 py-2.5 text-sm font-medium transition-colors ${
                  gender === option.value
                    ? "border-primary bg-primary-tint text-primary"
                    : "border-border bg-card text-ink-muted hover:border-primary/40"
                }`}
              >
                {dm.auth.onboarding.genderOptions[option.value]}
              </button>
            ))}
          </div>
        </div>
        {error && <p className="text-sm font-medium text-error">{error}</p>}
        <button
          type="submit"
          className="mt-2 rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          {dm.common.continueLabel}
        </button>
      </form>
    </>
  );
}
