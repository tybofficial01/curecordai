import type { Metadata } from "next";
import { Manrope, Noto_Nastaliq_Urdu } from "next/font/google";
import OrganizationSchema from "@/components/seo/OrganizationSchema";
import { siteConfig } from "@/content/site";
import { ConfirmDialogProvider } from "@/lib/dialog/ConfirmDialogProvider";
import { ToastProvider } from "@/lib/toast/ToastProvider";
import "./globals.css";

const manrope = Manrope({ subsets: ["latin"], display: "swap", variable: "--font-manrope" });

// Urdu-script UI (the `ur` locale - see i18n/routing.ts) reads in Noto Nastaliq Urdu
// everywhere instead of Manrope; enforced by the `html[data-locale="ur"]` rule in
// globals.css. Roman Urdu (`roman-ur`) is Latin-script and keeps Manrope like English.
const notoNastaliqUrdu = Noto_Nastaliq_Urdu({
  subsets: ["arabic"],
  weight: ["400", "700"],
  display: "swap",
  variable: "--font-noto-nastaliq-urdu",
});

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  title: {
    default: "AI Health Record App for Families | CurecordAI",
    template: "%s | CurecordAI",
  },
  description: siteConfig.description,
  keywords: [
    "health record app Pakistan",
    "AI health assistant Pakistan",
    "medical records organizer Pakistan",
    "family health app Urdu",
    "lab report explainer Pakistan",
    "digital health record Pakistan",
  ],
  authors: [{ name: "CurecordAI Team" }],
  creator: "CurecordAI",
  publisher: "CurecordAI",
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  // TODO: Add Google Search Console verification code here
  // verification: { google: '' },
  openGraph: {
    type: "website",
    locale: "en_PK",
    url: siteConfig.url,
    siteName: "CurecordAI",
    title: "AI Health Record App for Families | CurecordAI",
    description:
      "Organize your family medical history, understand your lab reports in plain Urdu or English, and share records with any doctor in one tap.",
    images: [
      {
        url: siteConfig.ogImage,
        width: 1200,
        height: 630,
        alt: "CurecordAI - AI Powered Health Records for Families",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "AI Health Record App for Pakistani Families | CurecordAI",
    description:
      "Organize your family medical history, understand your lab reports in plain Urdu or English, and share records with any doctor in one tap.",
    images: [siteConfig.ogImage],
  },
  alternates: {
    canonical: siteConfig.url,
  },
};

// Runs before hydration so the correct theme is set on <html> before first
// paint - reading this after mount would cause a visible flash of dark mode.
const themeInitScript = `(function(){try{var key="curecordai-theme";var stored=localStorage.getItem(key);var theme=stored==="light"||stored==="dark"?stored:(window.matchMedia("(prefers-color-scheme: light)").matches?"light":"dark");document.documentElement.setAttribute("data-theme",theme);}catch(e){}})();`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${manrope.variable} ${notoNastaliqUrdu.variable}`} suppressHydrationWarning>
      <head>
        {/* Warms the connection to Google's Sign-In endpoint so the GSI script
            and button iframe don't pay DNS/TLS setup cost when they load. */}
        <link rel="preconnect" href="https://accounts.google.com" />
        <link rel="dns-prefetch" href="https://accounts.google.com" />
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
      </head>
      <body className="min-h-screen bg-background font-sans text-ink antialiased">
        <OrganizationSchema />
        <ConfirmDialogProvider>
          <ToastProvider>{children}</ToastProvider>
        </ConfirmDialogProvider>
      </body>
    </html>
  );
}
