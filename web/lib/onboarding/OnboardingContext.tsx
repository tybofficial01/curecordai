"use client";

import { createContext, useContext, useMemo, useState, type ReactNode } from "react";

export const PENDING_NAME_KEY = "curecord_onboarding_full_name";

export const GENDER_OPTIONS = [
  { value: "male", label: "Male" },
  { value: "female", label: "Female" },
  { value: "other", label: "Other" },
  { value: "unknown", label: "Prefer not to say" },
] as const;

export const CONDITION_OPTIONS = ["Asthma", "Diabetes", "Epilepsy", "Hypertension", "Thyroid Issue"] as const;

export interface OnboardingStep1 {
  fullName: string;
  yearOfBirth: string;
  gender: string;
}

export interface OnboardingStep2 {
  heightCm: string;
  weightKg: string;
  bloodGroup: string;
}

export interface OnboardingStep3 {
  allergies: string;
  conditions: string[];
  otherConditions: string;
}

interface OnboardingContextValue {
  step1: OnboardingStep1;
  step2: OnboardingStep2;
  step3: OnboardingStep3;
  setStep1: (data: OnboardingStep1) => void;
  setStep2: (data: OnboardingStep2) => void;
  setStep3: (data: OnboardingStep3) => void;
}

const OnboardingContext = createContext<OnboardingContextValue | null>(null);

export function OnboardingProvider({
  children,
  initialFullName = "",
}: {
  children: ReactNode;
  initialFullName?: string;
}) {
  const [step1, setStep1] = useState<OnboardingStep1>({ fullName: initialFullName, yearOfBirth: "", gender: "" });
  const [step2, setStep2] = useState<OnboardingStep2>({ heightCm: "", weightKg: "", bloodGroup: "" });
  const [step3, setStep3] = useState<OnboardingStep3>({ allergies: "", conditions: [], otherConditions: "" });

  const value = useMemo(
    () => ({ step1, step2, step3, setStep1, setStep2, setStep3 }),
    [step1, step2, step3]
  );

  return <OnboardingContext.Provider value={value}>{children}</OnboardingContext.Provider>;
}

export function useOnboarding(): OnboardingContextValue {
  const ctx = useContext(OnboardingContext);
  if (!ctx) throw new Error("useOnboarding must be used within OnboardingProvider");
  return ctx;
}
