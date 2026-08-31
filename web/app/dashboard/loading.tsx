import { Skeleton } from "@/components/dashboard/Skeleton";

export default function DashboardLoading() {
  return (
    <div>
      <Skeleton className="h-6 w-48" />
      <Skeleton className="mt-2 h-4 w-72" />
      <div className="mt-8 grid gap-4 sm:grid-cols-2">
        <Skeleton className="h-24" />
        <Skeleton className="h-24" />
      </div>
      <div className="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
        <Skeleton className="h-32" />
      </div>
    </div>
  );
}
