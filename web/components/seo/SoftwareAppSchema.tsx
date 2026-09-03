import { siteConfig } from "@/content/site";

export default function SoftwareAppSchema() {
  const schema = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "CurecordAI",
    operatingSystem: "Android, iOS, Web",
    applicationCategory: "HealthApplication",
    offers: {
      "@type": "Offer",
      price: "0",
      priceCurrency: "PKR",
    },
    description:
      "AI powered personal health record app that organizes family medical history, explains records in plain Urdu or English, and enables one tap doctor sharing.",
    url: siteConfig.url,
  };

  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(schema) }}
    />
  );
}
