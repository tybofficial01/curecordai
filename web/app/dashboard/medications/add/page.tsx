"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

// The add-medication flow now lives in a modal on the Medications list page
// (see ../AddMedicationModal.tsx) instead of its own set of full pages. This
// route is kept only so existing links to it, such as the dashboard's quick
// action tile, still work: it redirects to the list page and asks it to open
// the modal right away.
export default function AddMedicationRedirect() {
  const router = useRouter();

  useEffect(() => {
    router.replace("/dashboard/medications?add=1");
  }, [router]);

  return null;
}
