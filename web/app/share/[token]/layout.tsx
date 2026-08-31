import type { Metadata } from "next";

// The doctor-facing share view is reached through a secret, time-limited token
// that identifies one patient's medical records. It must never be indexed,
// archived, or snippeted by a crawler that happens to see a shared link.
// page.tsx is a client component and so cannot export `metadata` itself; this
// layout carries it for the whole /share/[token] segment. app/robots.ts also
// disallows /share for crawlers that honour robots.txt - both together, since
// robots.txt only asks politely and these tokens are privacy-sensitive.
export const metadata: Metadata = {
  robots: {
    index: false,
    follow: false,
    noarchive: true,
    nosnippet: true,
    noimageindex: true,
  },
};

export default function ShareLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
