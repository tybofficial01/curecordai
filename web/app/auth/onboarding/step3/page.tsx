"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { OnboardingProgress } from "@/components/onboarding/OnboardingProgress";
import { CONDITION_OPTIONS, useOnboarding } from "@/lib/onboarding/OnboardingContext";
import { useAuth } from "@/lib/auth/AuthContext";
import { completeOnboarding } from "@/lib/api/users";
import { ApiError } from "@/lib/api/client";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

export default function OnboardingStep3Page() {
  const router = useRouter();
  const { getAccessToken } = useAuth();
  const { step1, step2, step3, setStep3 } = useOnboarding();
  const dm = useDashboardMessages();
  const [allergies, setAllergies] = useState(step3.allergies);
  const [conditions, setConditions] = useState<string[]>(step3.conditions);
  const [otherConditions, setOtherConditions] = useState(step3.otherConditions);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  function toggleCondition(condition: string) {
    setConditions((prev) =>
      prev.includes(condition) ? prev.filter((c) => c !== condition) : [...prev, condition]
    );
  }

  function buildPayload() {
    const allConditions = [
      ...conditions,
      ...otherConditions
        .split(",")
        .map((c) => c.trim())
        .filter(Boolean),
    ];
    return {
      full_name: step1.fullName || undefined,
      year_of_birth: step1.yearOfBirth ? Number(step1.yearOfBirth) : undefined,
      gender: step1.gender || undefined,
      height_cm: step2.heightCm ? Number(step2.heightCm) : undefined,
      weight_kg: step2.weightKg ? Number(step2.weightKg) : undefined,
      blood_group: step2.bloodGroup || undefined,
      allergies: allergies.trim() || undefined,
      existing_conditions: allConditions.length > 0 ? allConditions : undefined,
    };
  }

  async function handleFinish(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");
    setStep3({ allergies, conditions, otherConditions });
    setSubmitting(true);
    try {
      const token = await getAccessToken();
      if (token) {
        await completeOnboarding(token, buildPayload());
      }
      router.push("/dashboard");
    } catch (err) {
      setError(err instanceof ApiError ? err.message : dm.auth.onboarding.saveError);
    } finally {
      setSubmitting(false);
    }
  }

  function handleSkip() {
    router.push("/dashboard");
  }

  return (
    <>
      <OnboardingProgress step={3} />
      <h1 className="text-2xl font-bold text-ink">{dm.auth.onboarding.step3Title}</h1>
      <p className="mt-1 text-sm text-ink-muted">
        {dm.auth.onboarding.step3Description}
      </p>

      <form onSubmit={handleFinish} className="mt-6 flex flex-col gap-4" noValidate>
        <div>
          <label htmlFor="allergies" className="block text-sm font-medium text-ink">
            {dm.auth.onboarding.allergies}
          </label>
          <input
            id="allergies"
            type="text"
            placeholder={dm.auth.onboarding.allergiesPlaceholder}
            value={allergies}
            onChange={(e) => setAllergies(e.target.value)}
            className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
          />
          <p className="mt-1.5 text-xs text-ink-muted">{dm.auth.onboarding.allergiesHint}</p>
        </div>
        <div>
          <span className="block text-sm font-medium text-ink">{dm.auth.onboarding.existingConditions}</span>
          <div className="mt-1.5 flex flex-wrap gap-2">
            {CONDITION_OPTIONS.map((condition) => (
              <button
                key={condition}
                type="button"
                onClick={() => toggleCondition(condition)}
                className={`rounded-full border px-4 py-2 text-sm font-medium transition-colors ${
                  conditions.includes(condition)
                    ? "border-primary bg-primary-tint text-primary"
                    : "border-border bg-card text-ink-muted hover:border-primary/40"
                }`}
              >
                {dm.auth.onboarding.conditionOptions[condition]}
              </button>
            ))}
          </div>
        </div>
        <div>
          <label htmlFor="otherConditions" className="block text-sm font-medium text-ink">
            {dm.auth.onboarding.otherConditions}
          </label>
          <input
            id="otherConditions"
            type="text"
            placeholder={dm.auth.onboarding.otherConditionsPlaceholder}
            value={otherConditions}
            onChange={(e) => setOtherConditions(e.target.value)}
            className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
          />
          <p className="mt-1.5 text-xs text-ink-muted">{dm.auth.onboarding.otherConditionsHint}</p>
        </div>
        {error && <p className="text-sm font-medium text-error">{error}</p>}
        <div className="mt-2 flex flex-col gap-3 sm:flex-row-reverse">
          <button
            type="submit"
            disabled={submitting}
            className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 disabled:opacity-70 sm:flex-1"
          >
            {submitting ? dm.auth.onboarding.finishing : dm.auth.onboarding.finish}
          </button>
          <button
            type="button"
            onClick={() => router.push("/auth/onboarding/step2")}
            className="rounded-full border border-border px-6 py-3 text-base font-semibold text-ink transition-colors hover:bg-ink/5"
          >
            {dm.common.previous}
          </button>
        </div>
        <button
          type="button"
          onClick={handleSkip}
          disabled={submitting}
          className="text-sm font-medium text-ink-muted hover:text-primary disabled:opacity-70"
        >
          {dm.common.skipForNow}
        </button>
      </form>
    </>
  );
}
