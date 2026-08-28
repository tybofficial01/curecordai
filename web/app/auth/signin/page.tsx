import type { Metadata } from "next";
import { SignInView } from "@/components/auth/SignInView";
import { siteConfig } from "@/content/site";

export const metadata: Metadata = {
  title: "Sign In",
  description: "Sign in to your CurecordAI account to access your family health vault.",
  alternates: { canonical: `${siteConfig.url}/auth/signin` },
};

export default function SignInPage() {
  return <SignInView />;
}
