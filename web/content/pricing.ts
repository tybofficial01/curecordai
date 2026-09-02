// Plan name/price/period/description/features/cta are all translated under
// "pricing.plans.*" in messages/{locale}.json - only the stable key and the
// purely presentational "highlighted" flag live here.
export const pricingPlans = [
  { key: "individual", highlighted: false },
  { key: "family", highlighted: true },
] as const;
