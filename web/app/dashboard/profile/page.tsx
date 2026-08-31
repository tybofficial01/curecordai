"use client";

import { useEffect, useState, type FormEvent } from "react";
import Image from "next/image";
import { mutate as globalMutate } from "swr";
import { Camera, CheckCircle, SignOut } from "@phosphor-icons/react/dist/ssr";
import { useRouter } from "next/navigation";
import { useAuth } from "@/lib/auth/AuthContext";
import { useTheme } from "@/lib/useTheme";
import { useLocale } from "@/lib/locale/useLocale";
import { formatMessage, useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { useCachedResource } from "@/lib/hooks/useCachedResource";
import {
  getProfile,
  updateHealthDetails,
  updatePhysicalMetrics,
  updatePreferences,
  updateProfileInfo,
  uploadAvatar,
} from "@/lib/api/profile";
import { getAppSettings, updateAppSettings } from "@/lib/api/settings";
import { ApiError } from "@/lib/api/client";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { ToggleRow } from "@/components/dashboard/ToggleRow";
import { Skeleton } from "@/components/dashboard/Skeleton";
import { Select } from "@/components/ui/Select";
import { AvatarCropModal } from "@/components/dashboard/AvatarCropModal";
import { BLOOD_GROUPS, type AppLanguage } from "@/lib/api/types";
import { computeProfileCompletionPct } from "@/lib/profileCompletion";

type BooleanSettingField =
  | "push_notifications_enabled"
  | "email_notifications_enabled"
  | "lab_result_alerts"
  | "drug_interaction_alerts";

async function loadProfilePage(token: string) {
  const [profile, settings] = await Promise.all([getProfile(token), getAppSettings(token)]);
  return { profile, settings };
}

function SavedBadge({ saved, label }: { saved: boolean; label: string }) {
  if (!saved) return null;
  return (
    <span className="flex items-center gap-1 text-xs font-medium text-success">
      <CheckCircle size={14} /> {label}
    </span>
  );
}

export default function ProfilePage() {
  const { getAccessToken, signOut, user } = useAuth();
  const { theme, toggleTheme } = useTheme();
  const { language, setLanguage } = useLocale();
  const dm = useDashboardMessages();
  const router = useRouter();
  const { data, isLoading, error, setData } = useCachedResource("profile-page", loadProfilePage, {
    revalidateOnFocus: true,
  });

  const [fullName, setFullName] = useState("");
  const [phone, setPhone] = useState("");
  const [dob, setDob] = useState("");
  const [gender, setGender] = useState("");
  const [height, setHeight] = useState("");
  const [weight, setWeight] = useState("");
  const [bloodGroup, setBloodGroup] = useState("");
  const [allergies, setAllergies] = useState("");
  const [conditions, setConditions] = useState("");
  const [avatarUrl, setAvatarUrl] = useState<string | null>(null);
  const [avatarFailed, setAvatarFailed] = useState(false);
  const [patientId, setPatientId] = useState<string | null>(null);
  const [cropImageSrc, setCropImageSrc] = useState<string | null>(null);

  const completion = computeProfileCompletionPct({ fullName, dob, gender, bloodGroup, height, weight, avatarUrl });

  const [savedSection, setSavedSection] = useState<string | null>(null);
  const [error1, setError1] = useState("");

  useEffect(() => {
    if (!data) return;
    setFullName(data.profile.full_name);
    setPhone(data.profile.phone_number ?? "");
    setDob(data.profile.date_of_birth ?? "");
    setGender(data.profile.gender ?? "");
    setHeight(data.profile.height_cm?.toString() ?? "");
    setWeight(data.profile.weight_kg?.toString() ?? "");
    setBloodGroup(data.profile.blood_group ?? "");
    setAllergies(data.profile.allergies ?? "");
    setConditions(data.profile.conditions.join(", "));
    setLanguage(data.profile.language);
    setAvatarUrl(data.profile.profile_photo_url);
    setAvatarFailed(false);
    setPatientId(data.profile.patient_id_display);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data]);

  function flashSaved(section: string) {
    setSavedSection(section);
    setTimeout(() => setSavedSection((s) => (s === section ? null : s)), 2000);
  }

  async function handleSaveInfo(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError1("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      await updateProfileInfo(token, {
        full_name: fullName,
        date_of_birth: dob || null,
        gender: gender || null,
        phone_number: phone,
      });
      flashSaved("info");
    } catch (err) {
      setError1(err instanceof ApiError ? err.message : dm.profile.saveInfoError);
    }
  }

  async function handleSaveMetrics(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError1("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      await updatePhysicalMetrics(token, {
        height_cm: height ? Number(height) : null,
        weight_kg: weight ? Number(weight) : null,
        blood_group: bloodGroup || null,
      });
      flashSaved("metrics");
    } catch (err) {
      setError1(err instanceof ApiError ? err.message : dm.profile.saveMetricsError);
    }
  }

  async function handleSaveHealth(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError1("");
    try {
      const token = await getAccessToken();
      if (!token) throw new Error(dm.common.sessionExpired);
      await updateHealthDetails(token, {
        allergies,
        conditions: conditions
          .split(",")
          .map((c) => c.trim())
          .filter(Boolean),
      });
      flashSaved("health");
    } catch (err) {
      setError1(err instanceof ApiError ? err.message : dm.profile.saveHealthError);
    }
  }

  async function handleLanguageChange(next: AppLanguage) {
    // lib/locale/useLocale.ts applies lang/dir instantly, persists the choice to the
    // NEXT_LOCALE_APP cookie, then triggers a server refresh so next-intl's provider
    // (AppLocaleProvider) re-renders with the new locale's messages - a brief round trip,
    // not instant, since translated strings now come from the server-resolved catalog.
    setLanguage(next);
    const token = await getAccessToken();
    if (!token) return;
    // Bundles the live theme (from the account-wide html[data-theme] toggle) rather than a
    // stale local copy - PUT /profile/preferences replaces the whole row.
    await updatePreferences(token, { language: next, is_dark_theme: theme === "dark" });
    flashSaved("preferences");
  }

  async function handleAvatarChange(file: File) {
    const token = await getAccessToken();
    if (!token) return;
    try {
      const result = await uploadAvatar(token, file);
      setAvatarUrl(result.avatar_url);
      setAvatarFailed(false);
      // Write the new photo into this page's own cache entry so it survives the next
      // revalidation, and nudge the sidebar's separate "profile-switcher" cache to refetch -
      // otherwise the sidebar avatar keeps showing the old photo until a full reload.
      setData((prev) => (prev ? { ...prev, profile: { ...prev.profile, profile_photo_url: result.avatar_url } } : prev));
      if (user) globalMutate(`${user.id}:profile-switcher`);
    } catch (err) {
      setError1(err instanceof ApiError ? err.message : dm.profile.avatarError);
    }
  }

  function handleAvatarFileSelected(file: File) {
    setCropImageSrc(URL.createObjectURL(file));
  }

  function closeCropModal() {
    if (cropImageSrc) URL.revokeObjectURL(cropImageSrc);
    setCropImageSrc(null);
  }

  async function handleCropSave(blob: Blob) {
    closeCropModal();
    await handleAvatarChange(new File([blob], "avatar.jpg", { type: "image/jpeg" }));
  }

  async function handleSettingsToggle(field: BooleanSettingField, value: boolean) {
    const token = await getAccessToken();
    if (!token) return;
    try {
      const updated = await updateAppSettings(token, { [field]: value });
      setData((prev) => (prev ? { ...prev, settings: updated } : prev));
      flashSaved("settings");
    } catch (err) {
      setError1(err instanceof ApiError ? err.message : dm.profile.savePreferenceError);
    }
  }

  async function handleSignOut() {
    await signOut();
    router.replace("/auth/signin");
  }

  if (isLoading) {
    return (
      <div>
        <Skeleton className="h-7 w-56" />
        <Skeleton className="mt-2 h-4 w-80" />
        <Skeleton className="mt-6 h-32 rounded-2xl" />
        <div className="mt-8 grid gap-8 lg:grid-cols-[1fr_320px]">
          <div className="flex flex-col gap-6">
            <Skeleton className="h-64" />
            <Skeleton className="h-48" />
            <Skeleton className="h-40" />
          </div>
          <div className="flex flex-col gap-6">
            <Skeleton className="h-32" />
            <Skeleton className="h-40" />
          </div>
        </div>
      </div>
    );
  }
  if (error || !data) return <p className="text-sm text-error">{error ?? dm.profile.loadError}</p>;

  return (
    <div>
      <PageHeading title={dm.profile.title} description={dm.profile.description} />

      {/* Profile header: avatar, name, and patient ID alongside the completion indicator, kept
          as the first thing visible on the page rather than buried below other sections. */}
      <div className="mb-8 flex flex-col items-center gap-5 rounded-2xl border border-border bg-card p-6 text-center sm:flex-row sm:text-left">
        <label className="group relative inline-block shrink-0 cursor-pointer" aria-label={dm.profile.changePhoto}>
          <span className="flex h-20 w-20 items-center justify-center overflow-hidden rounded-full bg-primary-tint text-2xl font-bold text-primary">
            {avatarUrl && !avatarFailed ? (
              <Image
                src={avatarUrl}
                alt={fullName}
                width={80}
                height={80}
                className="h-full w-full object-cover"
                onError={() => setAvatarFailed(true)}
              />
            ) : (
              fullName.charAt(0).toUpperCase() || "?"
            )}
          </span>
          <span className="absolute bottom-0 right-0 flex h-7 w-7 items-center justify-center rounded-full border-2 border-card bg-primary text-primary-foreground transition-colors group-hover:bg-primary/90">
            <Camera size={14} weight="fill" />
          </span>
          <input
            type="file"
            accept="image/jpeg,image/png,image/webp"
            className="hidden"
            onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) handleAvatarFileSelected(file);
              e.target.value = "";
            }}
          />
        </label>

        <div className="w-full min-w-0 flex-1">
          <p className="text-base font-semibold text-ink">{fullName}</p>
          {patientId && <p className="text-xs text-ink-muted">{formatMessage(dm.profile.patientId, { id: patientId })}</p>}

          {/* Separated from the identity block above with a divider so the two read as distinct
              sections of the card rather than one continuous block. */}
          <div className="mt-4 border-t border-border pt-4">
            <div className="flex items-center justify-center gap-2 text-xs text-ink-muted sm:justify-between sm:gap-0">
              <span>{dm.profile.completion}</span>
              <span>{completion}%</span>
            </div>
            <div className="mt-1.5 h-2 w-full overflow-hidden rounded-full bg-surface">
              <div className="h-full rounded-full bg-primary" style={{ width: `${completion}%` }} />
            </div>
          </div>
        </div>
      </div>

      <div className="grid gap-8 lg:grid-cols-[1fr_320px]">
        <div className="flex flex-col gap-6">
          <div className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-ink">{dm.profile.personalInformation}</h2>
              <SavedBadge saved={savedSection === "info"} label={dm.profile.saved} />
            </div>
            <form onSubmit={handleSaveInfo} className="mt-4 flex flex-col gap-5" noValidate>
              <div>
                <label htmlFor="fullName" className="block text-sm font-medium text-ink">
                  {dm.profile.fullName}
                </label>
                <input
                  id="fullName"
                  type="text"
                  value={fullName}
                  onChange={(e) => setFullName(e.target.value)}
                  className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>
              <div>
                <label htmlFor="phone" className="block text-sm font-medium text-ink">
                  {dm.profile.phoneNumber}
                </label>
                <input
                  id="phone"
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>
              <div className="grid gap-5 sm:grid-cols-2">
                <div>
                  <label htmlFor="dob" className="block text-sm font-medium text-ink">
                    {dm.profile.dateOfBirth}
                  </label>
                  <input
                    id="dob"
                    type="date"
                    value={dob}
                    onChange={(e) => setDob(e.target.value)}
                    className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                  />
                </div>
                <div>
                  <label htmlFor="gender" className="block text-sm font-medium text-ink">
                    {dm.profile.gender}
                  </label>
                  <Select
                    id="gender"
                    value={gender}
                    onChange={setGender}
                    placeholder={dm.profile.preferNotToSay}
                    options={[
                      { value: "male", label: dm.profile.male },
                      { value: "female", label: dm.profile.female },
                    ]}
                    className="mt-1.5"
                  />
                </div>
              </div>
              {error1 && <p className="text-sm font-medium text-error">{error1}</p>}
              <button
                type="submit"
                className="self-start rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              >
                {dm.common.saveChanges}
              </button>
            </form>
          </div>

          <div className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-ink">{dm.profile.physicalMetrics}</h2>
              <SavedBadge saved={savedSection === "metrics"} label={dm.profile.saved} />
            </div>
            <form onSubmit={handleSaveMetrics} className="mt-4 grid gap-5 sm:grid-cols-3">
              <div>
                <label htmlFor="height" className="block text-sm font-medium text-ink">
                  {dm.profile.heightCm}
                </label>
                <input
                  id="height"
                  type="number"
                  min={50}
                  max={300}
                  value={height}
                  onChange={(e) => setHeight(e.target.value)}
                  className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>
              <div>
                <label htmlFor="weight" className="block text-sm font-medium text-ink">
                  {dm.profile.weightKg}
                </label>
                <input
                  id="weight"
                  type="number"
                  min={10}
                  max={500}
                  value={weight}
                  onChange={(e) => setWeight(e.target.value)}
                  className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>
              <div>
                <label htmlFor="bloodGroup" className="block text-sm font-medium text-ink">
                  {dm.profile.bloodGroup}
                </label>
                <Select
                  id="bloodGroup"
                  value={bloodGroup}
                  onChange={setBloodGroup}
                  placeholder={dm.profile.unknown}
                  options={BLOOD_GROUPS.map((bg) => ({ value: bg, label: bg }))}
                  className="mt-1.5"
                />
              </div>
              <button
                type="submit"
                className="col-span-full self-start rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              >
                {dm.profile.saveMetrics}
              </button>
            </form>
          </div>

          <div className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-ink">{dm.profile.healthDetails}</h2>
              <SavedBadge saved={savedSection === "health"} label={dm.profile.saved} />
            </div>
            <form onSubmit={handleSaveHealth} className="mt-4 flex flex-col gap-5">
              <div>
                <label htmlFor="allergies" className="block text-sm font-medium text-ink">
                  {dm.profile.allergiesLabel}
                </label>
                <input
                  id="allergies"
                  type="text"
                  placeholder={dm.profile.allergiesPlaceholder}
                  value={allergies}
                  onChange={(e) => setAllergies(e.target.value)}
                  className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>
              <div>
                <label htmlFor="conditions" className="block text-sm font-medium text-ink">
                  {dm.profile.conditionsLabel}
                </label>
                <input
                  id="conditions"
                  type="text"
                  placeholder={dm.profile.conditionsPlaceholder}
                  value={conditions}
                  onChange={(e) => setConditions(e.target.value)}
                  className="mt-1.5 w-full rounded-xl border border-border bg-card px-4 py-3 text-base text-ink outline-none focus:border-primary focus:ring-2 focus:ring-primary/20"
                />
              </div>
              <button
                type="submit"
                className="self-start rounded-full bg-primary px-6 py-3 text-sm font-semibold text-primary-foreground hover:bg-primary/90"
              >
                {dm.profile.saveHealthDetails}
              </button>
            </form>
          </div>
        </div>

        <div className="flex flex-col gap-6">
          <div className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-ink">{dm.profile.preferences}</h2>
              <SavedBadge saved={savedSection === "preferences"} label={dm.profile.saved} />
            </div>
            <div className="mt-2">
              <label htmlFor="language" className="block text-sm font-medium text-ink">
                {dm.profile.language}
              </label>
              <Select
                id="language"
                value={language}
                onChange={(v) => handleLanguageChange(v as AppLanguage)}
                options={[
                  { value: "en", label: dm.profile.languageNames.en },
                  { value: "ur", label: dm.profile.languageNames.ur },
                  { value: "roman_ur", label: dm.profile.languageNames.roman_ur },
                ]}
                className="mt-1.5 py-2.5 text-sm"
              />
            </div>
            <div className="mt-2 divide-y divide-border">
              <ToggleRow
                label={dm.profile.darkMode}
                description={dm.profile.darkModeDescription}
                checked={theme === "dark"}
                onChange={() => toggleTheme()}
              />
            </div>
          </div>

          <div className="rounded-2xl border border-border bg-card p-6">
            <div className="flex items-center justify-between">
              <h2 className="text-sm font-semibold text-ink">{dm.profile.notifications}</h2>
              <SavedBadge saved={savedSection === "settings"} label={dm.profile.saved} />
            </div>
            <div className="divide-y divide-border">
              <ToggleRow
                label={dm.profile.pushNotifications}
                checked={data.settings.push_notifications_enabled}
                onChange={(v) => handleSettingsToggle("push_notifications_enabled", v)}
              />
              <ToggleRow
                label={dm.profile.emailNotifications}
                checked={data.settings.email_notifications_enabled}
                onChange={(v) => handleSettingsToggle("email_notifications_enabled", v)}
              />
              <ToggleRow
                label={dm.profile.labResultAlerts}
                checked={data.settings.lab_result_alerts}
                onChange={(v) => handleSettingsToggle("lab_result_alerts", v)}
              />
              <ToggleRow
                label={dm.profile.drugInteractionAlerts}
                checked={data.settings.drug_interaction_alerts}
                onChange={(v) => handleSettingsToggle("drug_interaction_alerts", v)}
              />
            </div>
          </div>

          <button
            type="button"
            onClick={handleSignOut}
            className="flex items-center justify-center gap-2 rounded-full border border-error px-6 py-3 text-sm font-semibold text-error hover:bg-error/5"
          >
            <SignOut size={18} /> {dm.nav.signOut}
          </button>
        </div>
      </div>

      {cropImageSrc && (
        <AvatarCropModal imageSrc={cropImageSrc} onCancel={closeCropModal} onSave={handleCropSave} />
      )}
    </div>
  );
}
