import type { Metadata } from "next";
import { Button } from "@/components/ui/Button";
import { Container } from "@/components/ui/Container";

export const metadata: Metadata = {
  title: "Launching Soon",
  robots: { index: false, follow: false },
};

export default function ComingSoonPage() {
  return (
    <section className="flex min-h-[70vh] items-center bg-surface py-16 sm:py-20">
      <Container className="max-w-2xl text-center">
        <p className="text-sm font-semibold uppercase tracking-wide text-primary">
          Launching Soon
        </p>
        <h1 className="mt-3 text-4xl font-bold tracking-tight text-ink sm:text-5xl">
          The CurecordAI app is almost here
        </h1>
        <p className="mt-4 text-lg text-ink-muted">
          We&apos;re putting the finishing touches on the app. In the meantime, learn more about
          what CurecordAI does and how it works.
        </p>
        <div className="mt-8 flex flex-wrap items-center justify-center gap-4">
          <Button href="/">Back to Home</Button>
          <Button href="/contact" variant="secondary">
            Contact Us
          </Button>
        </div>
      </Container>
    </section>
  );
}
