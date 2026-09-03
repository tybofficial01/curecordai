"use client";

import { useState } from "react";
import { CaretDown } from "@phosphor-icons/react/dist/ssr";

interface FAQItem {
  question: string;
  answer: string;
}

export function FAQAccordion({ faqs }: { faqs: FAQItem[] }) {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <div className="flex flex-col divide-y divide-border rounded-2xl border border-border bg-card">
      {faqs.map((faq, index) => {
        const isOpen = openIndex === index;
        const panelId = `faq-panel-${index}`;
        const buttonId = `faq-button-${index}`;
        return (
          <div key={faq.question}>
            <h3>
              <button
                type="button"
                id={buttonId}
                onClick={() => setOpenIndex(isOpen ? null : index)}
                aria-expanded={isOpen}
                aria-controls={panelId}
                className="flex w-full items-center justify-between gap-4 px-6 py-5 text-start"
              >
                <span className="text-base font-semibold text-ink">{faq.question}</span>
                <CaretDown
                  size={20}
                  className={`shrink-0 text-primary transition-transform ${isOpen ? "rotate-180" : ""}`}
                />
              </button>
            </h3>
            {/* Answer stays mounted in the DOM at all times (hidden via the native `hidden`
                attribute rather than conditional rendering) so every FAQ's text is present in
                the initial HTML for search/AI crawlers, not just whichever item is open. */}
            <div id={panelId} role="region" aria-labelledby={buttonId} hidden={!isOpen} className="px-6 pb-5">
              <p className="text-sm leading-relaxed text-ink-muted">{faq.answer}</p>
            </div>
          </div>
        );
      })}
    </div>
  );
}
