import { siteConfig } from "@/content/site";

export default function OrganizationSchema() {
  const schema = {
    "@context": "https://schema.org",
    "@type": "Organization",
    name: "CurecordAI",
    url: siteConfig.url,
    logo: `${siteConfig.url}/logo.png`,
    sameAs: ["https://www.linkedin.com/company/curecordai"],
    contactPoint: {
      "@type": "ContactPoint",
      contactType: "customer support",
      availableLanguage: ["English", "Urdu"],
    },
    areaServed: "PK",
    description:
      "CurecordAI is an AI powered personal health record system for patients and families in Pakistan.",
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}
