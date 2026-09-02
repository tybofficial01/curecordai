export const siteConfig = {
  name: "CurecordAI",
  url: "https://curecordai.com",
  description:
    "CurecordAI organizes your family's complete medical history in one place and explains lab reports and complex medical documents in plain Urdu or English.",
  ogImage: "/og-default.png",
  // Kept in sync with the backend's CONTACT_INBOX_EMAIL default (be/app/config.py) - the
  // inbox the contact form actually forwards to.
  supportEmail: "support@curecordai.com",
};

// Each entry links to its own standalone page rather than a homepage anchor
// (Navbar.tsx branches on an "/#" prefix and only intercepts clicks / runs
// scroll-spy for entries that still use one - none currently do, so every
// link here is a plain page navigation). The homepage keeps its own
// features/how-it-works/pricing/FAQ sections; primary nav just no longer
// routes through them.
// `labelKey` looks up the "nav.*" / "footer.links.*" message keys in
// messages/{locale}.json (see components/marketing/Navbar.tsx and Footer.tsx)
// so link labels render in the active marketing-site locale; `href` stays
// locale-agnostic since the locale-aware <Link> from i18n/navigation adds
// the "/en" | "/ur" | "/roman-ur" prefix automatically.
export const marketingNavLinks = [
  { href: "/features", labelKey: "features" },
  { href: "/how-it-works", labelKey: "howItWorks" },
  { href: "/pricing", labelKey: "pricing" },
  { href: "/faq", labelKey: "faq" },
  { href: "/blog", labelKey: "blog" },
] as const;

export const footerLinkGroups = [
  {
    headingKey: "product",
    links: [
      { href: "/features", labelKey: "features" },
      { href: "/how-it-works", labelKey: "howItWorks" },
      { href: "/pricing", labelKey: "pricing" },
      { href: "/faq", labelKey: "faq" },
    ],
  },
  {
    headingKey: "company",
    links: [
      { href: "/about", labelKey: "about" },
      { href: "/contact", labelKey: "contact" },
      { href: "/blog", labelKey: "blog" },
    ],
  },
  {
    headingKey: "legal",
    links: [{ href: "/privacy", labelKey: "privacy" }],
  },
  {
    headingKey: "account",
    links: [
      { href: "/auth/signin", labelKey: "signIn" },
      { href: "/auth/signup", labelKey: "getStarted" },
    ],
  },
] as const;

export const socialLinks = [
  { href: "https://www.linkedin.com/company/curecordai", label: "LinkedIn" },
  { href: "https://twitter.com/curecordai", label: "Twitter" },
  { href: "https://instagram.com/curecordai", label: "Instagram" },
];
