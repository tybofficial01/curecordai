import type { Metadata } from "next";
import { SignUpView } from "@/components/auth/SignUpView";
import { siteConfig } from "@/content/site";

export const metadata: Metadata = {
  title: "Get Started",
  description: "Create your free CurecordAI account and start organizing your family's health records.",
  alternates: { canonical: `${siteConfig.url}/auth/signup` },
};

export default function SignUpPage() {
  return <SignUpView />;
}
