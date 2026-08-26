import type { Metadata } from "next";
import { Container } from "@/components/ui/Container";
import { Button } from "@/components/ui/Button";

export const metadata: Metadata = {
  title: "Page Not Found",
  robots: { index: false, follow: true },
};

export default function NotFound() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-surface">
      <Container className="max-w-md text-center">
        <p className="text-sm font-semibold uppercase tracking-wide text-primary">Error 404</p>
        <h1 className="mt-3 text-4xl font-bold text-ink">Page not found</h1>
        <p className="mt-4 text-base text-ink-muted">
          The page you are looking for does not exist or may have moved.
        </p>
        <div className="mt-8 flex justify-center">
          <Button href="/">Go back to homepage</Button>
        </div>
      </Container>
    </div>
  );
}
