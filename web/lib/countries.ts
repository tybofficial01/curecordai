export interface Country {
  name: string;
  iso2: string;
  dialCode: string;
}

// Flag rendered from the ISO 3166-1 alpha-2 code via Unicode regional indicator
// symbols - no image assets or extra dependency needed.
export function flagEmoji(iso2: string): string {
  return String.fromCodePoint(...[...iso2.toUpperCase()].map((c) => 127397 + c.charCodeAt(0)));
}

// Common countries first (Pakistan default, matching the product's primary market),
// then the rest alphabetically by name - mirrors how industry-standard phone inputs
// (Intl-tel-input, MUI, etc.) group a "preferred" set above the full list.
export const COUNTRIES: Country[] = [
  { name: "Pakistan", iso2: "PK", dialCode: "+92" },
  { name: "United States", iso2: "US", dialCode: "+1" },
  { name: "United Kingdom", iso2: "GB", dialCode: "+44" },
  { name: "United Arab Emirates", iso2: "AE", dialCode: "+971" },
  { name: "Saudi Arabia", iso2: "SA", dialCode: "+966" },
  { name: "India", iso2: "IN", dialCode: "+91" },
  { name: "Afghanistan", iso2: "AF", dialCode: "+93" },
  { name: "Australia", iso2: "AU", dialCode: "+61" },
  { name: "Bahrain", iso2: "BH", dialCode: "+973" },
  { name: "Bangladesh", iso2: "BD", dialCode: "+880" },
  { name: "Canada", iso2: "CA", dialCode: "+1" },
  { name: "China", iso2: "CN", dialCode: "+86" },
  { name: "Egypt", iso2: "EG", dialCode: "+20" },
  { name: "France", iso2: "FR", dialCode: "+33" },
  { name: "Germany", iso2: "DE", dialCode: "+49" },
  { name: "Indonesia", iso2: "ID", dialCode: "+62" },
  { name: "Ireland", iso2: "IE", dialCode: "+353" },
  { name: "Italy", iso2: "IT", dialCode: "+39" },
  { name: "Japan", iso2: "JP", dialCode: "+81" },
  { name: "Kuwait", iso2: "KW", dialCode: "+965" },
  { name: "Malaysia", iso2: "MY", dialCode: "+60" },
  { name: "Nepal", iso2: "NP", dialCode: "+977" },
  { name: "Netherlands", iso2: "NL", dialCode: "+31" },
  { name: "New Zealand", iso2: "NZ", dialCode: "+64" },
  { name: "Nigeria", iso2: "NG", dialCode: "+234" },
  { name: "Norway", iso2: "NO", dialCode: "+47" },
  { name: "Oman", iso2: "OM", dialCode: "+968" },
  { name: "Philippines", iso2: "PH", dialCode: "+63" },
  { name: "Qatar", iso2: "QA", dialCode: "+974" },
  { name: "Singapore", iso2: "SG", dialCode: "+65" },
  { name: "South Africa", iso2: "ZA", dialCode: "+27" },
  { name: "South Korea", iso2: "KR", dialCode: "+82" },
  { name: "Spain", iso2: "ES", dialCode: "+34" },
  { name: "Sri Lanka", iso2: "LK", dialCode: "+94" },
  { name: "Sweden", iso2: "SE", dialCode: "+46" },
  { name: "Switzerland", iso2: "CH", dialCode: "+41" },
  { name: "Turkey", iso2: "TR", dialCode: "+90" },
];

export const DEFAULT_COUNTRY = COUNTRIES[0];

export function findCountryByDialCode(dialCode: string): Country | undefined {
  return COUNTRIES.find((c) => c.dialCode === dialCode);
}
