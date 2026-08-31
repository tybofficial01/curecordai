"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import { getPublicShare, submitDoctorInstructions, type PublicSharePayload } from "@/lib/api/share";
import { ApiError } from "@/lib/api/client";

const SCOPE_LABELS: Record<string, string> = {
  full: "Complete Health History",
  last_1_year: "Last 1 Year",
  last_6_months: "Last 6 Months",
  emergency_only: "Emergency Summary Only",
};

function formatDateTime(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" });
}

function formatDate(value: string | null | undefined) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleDateString(undefined, { dateStyle: "medium" });
}

// Every color here is a literal black/white/gray value, never a themed token - this page is a
// standardized clinical document meant to print and read the same for every doctor, regardless
// of the viewer's device theme.
function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="border border-black py-4 px-5">
      <h2 className="mb-3 border-b border-black pb-2 text-xs font-bold uppercase tracking-widest text-black">
        {title}
      </h2>
      {children}
    </section>
  );
}

// Plain black/white block (never a themed color, matching this page's print-document look) so
// the summary reads as "already loading" the instant the link opens, instead of a blank page.
function SkeletonBlock({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse border border-black/20 bg-black/5 ${className}`} />;
}

function ShareSkeleton() {
  return (
    <div role="status" aria-label="Loading shared health summary" className="flex flex-col gap-4">
      <div className="border-b-4 border-black pb-4">
        <SkeletonBlock className="h-3 w-48" />
        <SkeletonBlock className="mt-2 h-7 w-64" />
        <SkeletonBlock className="mt-2 h-4 w-56" />
      </div>
      <div className="mt-2 flex flex-col gap-4">
        {Array.from({ length: 3 }).map((_, i) => (
          <SkeletonBlock key={i} className="h-24" />
        ))}
      </div>
    </div>
  );
}

function Tag({ children, strong = false }: { children: React.ReactNode; strong?: boolean }) {
  return (
    <span
      className={`m-1 inline-block border border-black px-3 py-1 text-sm text-black ${
        strong ? "font-bold underline" : ""
      }`}
    >
      {children}
    </span>
  );
}

export default function SharePage() {
  const params = useParams<{ token: string }>();
  const token = params.token;

  const [data, setData] = useState<PublicSharePayload | null>(null);
  const [loadError, setLoadError] = useState("");
  const [loading, setLoading] = useState(true);

  const [showForm, setShowForm] = useState(false);
  const [doctorName, setDoctorName] = useState("");
  const [doctorInstitution, setDoctorInstitution] = useState("");
  const [instructions, setInstructions] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [submitError, setSubmitError] = useState("");
  const [submitted, setSubmitted] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        const payload = await getPublicShare(token);
        if (!cancelled) setData(payload);
      } catch (err) {
        if (!cancelled) setLoadError(err instanceof ApiError ? err.message : "Could not load this shared record.");
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token]);

  async function handleSubmitInstructions(e: React.FormEvent) {
    e.preventDefault();
    setSubmitError("");
    if (!doctorName.trim() || !doctorInstitution.trim() || !instructions.trim()) {
      setSubmitError("Please fill in your name, institution, and instructions.");
      return;
    }
    setSubmitting(true);
    try {
      await submitDoctorInstructions(token, {
        doctor_name: doctorName.trim(),
        doctor_institution: doctorInstitution.trim(),
        instructions: instructions.trim(),
      });
      setSubmitted(true);
    } catch (err) {
      setSubmitError(err instanceof ApiError ? err.message : "Could not send your instructions. Please try again.");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="min-h-screen bg-white px-4 py-10 text-black print:py-0">
      <div className="mx-auto max-w-2xl">
        {loading && <ShareSkeleton />}

        {!loading && loadError && (
          <div className="border border-black p-8 text-center">
            <h1 className="text-lg font-bold text-black">This link couldn&apos;t be opened</h1>
            <p className="mt-2 text-sm text-black">{loadError}</p>
          </div>
        )}

        {!loading && !loadError && data?.expired && (
          <div className="border border-black p-8 text-center">
            <h1 className="text-lg font-bold text-black">This QR code has expired or is invalid</h1>
            <p className="mt-2 text-sm text-black">
              Please ask the patient to generate a new QR code from their CurecordAI app.
            </p>
          </div>
        )}

        {!loading && !loadError && data && !data.expired && (
          <>
            <header className="border-b-4 border-black pb-4">
              <p className="text-xs font-semibold uppercase tracking-widest text-black">CurecordAI · Shared Health Summary</p>
              <h1 className="mt-1 text-2xl font-bold text-black">{data.patient_name || "Patient"}</h1>
              <p className="mt-1 text-sm text-black">
                {SCOPE_LABELS[data.scope ?? ""] ?? data.scope} access · Expires {formatDateTime(data.expires_at)}
              </p>
            </header>

            <div className="mt-6 flex flex-col gap-4 print:gap-3">
              {data.blood_group && (
                <Section title="Blood Group">
                  <Tag>{data.blood_group}</Tag>
                </Section>
              )}

              {!!data.emergency_contacts?.length && (
                <Section title="Emergency Contacts">
                  {data.emergency_contacts.map((c, i) => (
                    <Tag key={i}>
                      {c.full_name}
                      {c.relationship ? ` (${c.relationship})` : ""} - {c.phone_number}
                    </Tag>
                  ))}
                </Section>
              )}

              {!!data.allergies?.length && (
                <Section title="Allergies">
                  {data.allergies.map((a, i) => (
                    <Tag key={i} strong={a.criticality === "high"}>
                      {a.substance_name}
                      {a.criticality === "high" ? " (HIGH RISK)" : ""}
                    </Tag>
                  ))}
                </Section>
              )}

              {!!data.conditions?.length && (
                <Section title="Active Conditions">
                  {data.conditions.map((c, i) => (
                    <Tag key={i}>{c.condition_name}</Tag>
                  ))}
                </Section>
              )}

              {!!data.medications?.length && (
                <Section title="Current Medications">
                  {data.medications.map((m, i) => (
                    <Tag key={i}>
                      {m.display_name}
                      {m.dosage_instruction ? ` - ${m.dosage_instruction}` : ""}
                    </Tag>
                  ))}
                </Section>
              )}

              {!!data.observations?.length && (
                <Section title="Recent Lab Results / Vitals">
                  {data.observations.map((o, i) => (
                    <Tag key={i}>
                      {o.observation_name}: {o.value_quantity ?? o.value_string} {o.value_unit ?? ""}
                    </Tag>
                  ))}
                </Section>
              )}

              {!!data.encounters?.length && (
                <Section title="Recent Visits">
                  {data.encounters.map((e, i) => (
                    <Tag key={i}>
                      {e.title}
                      {formatDate(e.start_datetime) ? ` - ${formatDate(e.start_datetime)}` : ""}
                    </Tag>
                  ))}
                </Section>
              )}
            </div>

            <p className="mt-6 border-t border-black pt-4 text-xs text-black">
              This health summary was shared by the patient for informational purposes only. CurecordAI is not
              responsible for clinical decisions made based on this data. Always verify information directly with
              the patient.
            </p>

            <div className="mt-4 flex justify-center print:hidden">
              <button
                type="button"
                onClick={() => window.print()}
                className="border border-black px-4 py-2 text-sm font-semibold text-black hover:bg-black hover:text-white"
              >
                Print / Save as PDF
              </button>
            </div>

            <div className="mt-10 border border-black p-5 print:hidden">
              {submitted ? (
                <p className="text-sm font-semibold text-black">
                  Thank you - your instructions have been sent to the patient.
                </p>
              ) : (
                <>
                  <h2 className="text-sm font-bold uppercase tracking-widest text-black">
                    Leave instructions for the patient
                  </h2>
                  <p className="mt-1 text-xs text-black">
                    Optional. Anything you note here will be shown to the patient in their CurecordAI app.
                  </p>

                  {!showForm ? (
                    <button
                      type="button"
                      onClick={() => setShowForm(true)}
                      className="mt-4 border border-black px-4 py-2 text-sm font-semibold text-black hover:bg-black hover:text-white"
                    >
                      Add instructions
                    </button>
                  ) : (
                    <form onSubmit={handleSubmitInstructions} className="mt-4 flex flex-col gap-3">
                      <div className="grid gap-3 sm:grid-cols-2">
                        <label className="flex flex-col gap-1 text-xs font-semibold text-black">
                          Your name
                          <input
                            type="text"
                            value={doctorName}
                            onChange={(e) => setDoctorName(e.target.value)}
                            maxLength={255}
                            required
                            className="border border-black bg-white px-3 py-2 text-sm text-black outline-none"
                          />
                        </label>
                        <label className="flex flex-col gap-1 text-xs font-semibold text-black">
                          Hospital / Clinic
                          <input
                            type="text"
                            value={doctorInstitution}
                            onChange={(e) => setDoctorInstitution(e.target.value)}
                            maxLength={255}
                            required
                            className="border border-black bg-white px-3 py-2 text-sm text-black outline-none"
                          />
                        </label>
                      </div>
                      <label className="flex flex-col gap-1 text-xs font-semibold text-black">
                        Instructions for the patient
                        <textarea
                          value={instructions}
                          onChange={(e) => setInstructions(e.target.value)}
                          maxLength={4000}
                          required
                          rows={5}
                          className="border border-black bg-white px-3 py-2 text-sm text-black outline-none"
                        />
                      </label>

                      {submitError && <p className="text-sm font-semibold text-black">{submitError}</p>}

                      <button
                        type="submit"
                        disabled={submitting}
                        className="self-start border border-black bg-black px-4 py-2 text-sm font-semibold text-white disabled:opacity-60"
                      >
                        {submitting ? "Sending…" : "Send to patient"}
                      </button>
                    </form>
                  )}
                </>
              )}
            </div>
          </>
        )}
      </div>
    </div>
  );
}
