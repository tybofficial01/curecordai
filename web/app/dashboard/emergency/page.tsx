"use client";

import { DeviceMobile } from "@phosphor-icons/react/dist/ssr";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";
import { PageHeading } from "@/components/dashboard/PageHeading";
import { EmptyState } from "@/components/dashboard/EmptyState";

export default function EmergencyPage() {
  const dm = useDashboardMessages();

  return (
    <div>
      <PageHeading title={dm.emergency.title} description={dm.emergency.description} />

      <EmptyState
        icon={DeviceMobile}
        title={dm.emergency.emptyTitle}
        description={dm.emergency.emptyDescription}
      />
    </div>
  );
}
