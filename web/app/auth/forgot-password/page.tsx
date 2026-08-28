import type { Metadata } from "next";
import { ForgotPasswordForm } from "@/components/auth/ForgotPasswordForm";
import { siteConfig } from "@/content/site";

export const metadata: Metadata = {
  title: "Reset Password",
  description: "Reset the password for your CurecordAI account.",
  alternates: { canonical: `${siteConfig.url}/auth/forgot-password` },
};

export default function ForgotPasswordPage() {
  return <ForgotPasswordForm />;
}
