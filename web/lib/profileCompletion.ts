// Mirrors the backend's _recalc_completion (be/app/api/v1/profile.py) - same 7 fields, same
// truncating average. Computed client-side from the profile fields themselves rather than
// trusting the persisted profile_completion_pct column, which only gets recalculated by a
// handful of save endpoints and can go stale (e.g. after fields change via an endpoint that
// doesn't touch it) - deriving it here keeps every screen that shows the percentage in sync.
export function computeProfileCompletionPct(fields: {
  fullName: string;
  dob: string | null;
  gender: string | null;
  bloodGroup: string | null;
  height: string | number | null;
  weight: string | number | null;
  avatarUrl: string | null;
}): number {
  const values = [
    fields.fullName.trim(),
    fields.dob,
    fields.gender,
    fields.bloodGroup,
    fields.height,
    fields.weight,
    fields.avatarUrl,
  ];
  const filled = values.filter((v) => v !== null && v !== undefined && v !== "").length;
  return Math.floor((filled / values.length) * 100);
}
