"use client";

import { useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { OnboardingProgress } from "@/components/onboarding/OnboardingProgress";
import { useOnboarding } from "@/lib/onboarding/OnboardingContext";
import { BLOOD_GROUPS } from "@/lib/api/types";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

export default function OnboardingStep2Page() {
  const router = useRouter();
  const { step2, setStep2 } = useOnboarding();
  const dm = useDashboardMessages();
  const [heightCm, setHeightCm] = useState(step2.heightCm);
  const [weightKg, setWeightKg] = useState(step2.weightKg);
  const [bloodGroup, setBloodGroup] = useState(step2.bloodGroup);
  const [error, setError] = useState("");

  function persist() {
    setStep2({ heightCm, weightKg, bloodGroup });
  }

  function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError("");

    if (heightCm && (Number(heightCm) < 50 || Number(heightCm) > 300)) {
      setError(dm.auth.onboarding.invalidHeight);
      return;
    }
    if (weightKg && (Number(weightKg) < 1 || Number(weightKg) > 500)) {
      setError(dm.auth.onboarding.invalidWeight);
      return;
    }

    persist();
    router.push("/auth/onboarding/step3");
  }

  function handleSkip() {
    persist();
    router.push("/auth/onboarding/step3");
  }

  return (
    <>
      <OnboardingProgress step={2} />
      <h1 className="text-2xl font-bold text-ink">{dm.auth.onboarding.step2Title}</h1>
      <p className="mt-1 text-sm text-ink-muted">{dm.auth.onboarding.step2Description}</p>

      <form onSubmit={handleSubmit} className="mt-6 flex flex-col gap-4" noValidate>
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <div>
            <label htmlFor="heightCm" className="block text-sm font-medium text-ink">
              {dm.auth.onboarding.heightCm}
            </label>
            <input
              id="heightCm"
              type="text"
              inputMode="decimal"
              value={heightCm}
              onChange={(e) => setHeightCm(e.target.value.replace(/[^\d.]/g, ""))}
              className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
          </div>
          <div>
            <label htmlFor="weightKg" className="block text-sm font-medium text-ink">
              {dm.auth.onboarding.weightKg}
            </label>
            <input
              id="weightKg"
              type="text"
              inputMode="decimal"
              value={weightKg}
              onChange={(e) => setWeightKg(e.target.value.replace(/[^\d.]/g, ""))}
              className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
            />
          </div>
        </div>
        <div>
          <span className="block text-sm font-medium text-ink">{dm.auth.onboarding.bloodGroup}</span>
          <div className="mt-1.5 grid grid-cols-4 gap-2">
            {BLOOD_GROUPS.map((group) => (
              <button
                key={group}
                type="button"
                onClick={() => setBloodGroup(bloodGroup === group ? "" : group)}
                className={`rounded-xl border px-3 py-2.5 text-sm font-medium transition-colors ${
                  bloodGroup === group
                    ? "border-primary bg-primary-tint text-primary"
                    : "border-border bg-card text-ink-muted hover:border-primary/40"
                }`}
              >
                {group}
              </button>
            ))}
          </div>
        </div>
        {error && <p className="text-sm font-medium text-error">{error}</p>}
        <div className="mt-2 flex flex-col gap-3 sm:flex-row-reverse">
          <button
            type="submit"
            className="rounded-full bg-primary px-6 py-3 text-base font-semibold text-primary-foreground transition-colors hover:bg-primary/90 sm:flex-1"
          >
            {dm.common.continueLabel}
          </button>
          <button
            type="button"
            onClick={() => router.push("/auth/onboarding/step1")}
            className="rounded-full border border-border px-6 py-3 text-base font-semibold text-ink transition-colors hover:bg-ink/5"
          >
            {dm.common.previous}
          </button>
        </div>
        <button
          type="button"
          onClick={handleSkip}
          className="text-sm font-medium text-ink-muted hover:text-primary"
        >
          {dm.common.skipForNow}
        </button>
      </form>
    </>
  );
}
