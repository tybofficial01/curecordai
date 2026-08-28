"use client";

import { useEffect, useRef, useState } from "react";
import { CaretDown } from "@phosphor-icons/react/dist/ssr";
import { COUNTRIES, flagEmoji, type Country } from "@/lib/countries";
import { useDashboardMessages } from "@/lib/locale/dashboardMessages";

export function CountryCodeSelect({
  value,
  onChange,
}: {
  value: Country;
  onChange: (country: Country) => void;
}) {
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const dm = useDashboardMessages();

  useEffect(() => {
    if (!open) return;
    function handleClickOutside(event: MouseEvent) {
      if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, [open]);

  return (
    <div ref={containerRef} className="relative shrink-0">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={dm.auth.selectCountryCode}
        className="flex h-full items-center gap-1.5 rounded-s-xl border border-e-0 border-border bg-card px-3 py-3 text-base text-ink outline-none hover:bg-surface focus:border-primary focus:ring-2 focus:ring-primary/20"
      >
        <span className="text-lg leading-none" aria-hidden>
          {flagEmoji(value.iso2)}
        </span>
        <span className="font-medium">{value.dialCode}</span>
        <CaretDown size={12} className="text-ink-faint" />
      </button>

      {open && (
        <ul
          role="listbox"
          className="absolute start-0 top-full z-20 mt-1.5 max-h-64 w-64 overflow-y-auto rounded-xl border border-border bg-card py-1.5 shadow-lg"
        >
          {COUNTRIES.map((country) => (
            <li key={country.iso2}>
              <button
                type="button"
                role="option"
                aria-selected={country.iso2 === value.iso2}
                onClick={() => {
                  onChange(country);
                  setOpen(false);
                }}
                className={`flex w-full items-center gap-2.5 px-3 py-2 text-start text-sm hover:bg-surface ${
                  country.iso2 === value.iso2 ? "bg-primary-tint text-primary" : "text-ink"
                }`}
              >
                <span className="text-base leading-none" aria-hidden>
                  {flagEmoji(country.iso2)}
                </span>
                <span className="flex-1 truncate">{country.name}</span>
                <span className="text-ink-faint">{country.dialCode}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
