"use client";

import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";

/**
 * Renders AI chat replies (which come back as Markdown - bold, bullet lists, etc. per
 * CHAT_SYSTEM in be/app/services/prompts.py) as formatted text instead of raw asterisks.
 * react-markdown renders to React elements rather than dangerouslySetInnerHTML, so patient
 * message content can never inject raw HTML/scripts here.
 */
export function ChatMarkdown({ content }: { content: string }) {
  return (
    <ReactMarkdown
      remarkPlugins={[remarkGfm]}
      components={{
        p: ({ children }) => <p className="mb-2.5 last:mb-0">{children}</p>,
        strong: ({ children }) => <strong className="font-semibold">{children}</strong>,
        em: ({ children }) => <em className="italic">{children}</em>,
        ul: ({ children }) => <ul className="mb-2.5 ms-4 list-disc space-y-2 last:mb-0">{children}</ul>,
        ol: ({ children }) => <ol className="mb-2.5 ms-4 list-decimal space-y-2 last:mb-0">{children}</ol>,
        li: ({ children }) => <li>{children}</li>,
        // Sub-headers the model uses to break up a long answer into scannable sections
        // (e.g. "## HDL Cholesterol") - teal, bold, and set apart from body text.
        h1: ({ children }) => <h4 className="mb-1.5 mt-3.5 text-[14px] font-bold text-primary-dark first:mt-0">{children}</h4>,
        h2: ({ children }) => <h4 className="mb-1.5 mt-3.5 text-[14px] font-bold text-primary-dark first:mt-0">{children}</h4>,
        h3: ({ children }) => <h4 className="mb-1.5 mt-3.5 text-[14px] font-bold text-primary-dark first:mt-0">{children}</h4>,
        h4: ({ children }) => <h4 className="mb-1.5 mt-3.5 text-[14px] font-bold text-primary-dark first:mt-0">{children}</h4>,
        h5: ({ children }) => <h4 className="mb-1.5 mt-3.5 text-[14px] font-bold text-primary-dark first:mt-0">{children}</h4>,
        h6: ({ children }) => <h4 className="mb-1.5 mt-3.5 text-[14px] font-bold text-primary-dark first:mt-0">{children}</h4>,
        a: ({ href, children }) => (
          <a href={href} target="_blank" rel="noopener noreferrer" className="underline underline-offset-2">
            {children}
          </a>
        ),
        code: ({ children }) => (
          <code className="rounded bg-card px-1 py-0.5 text-[13px]">{children}</code>
        ),
        blockquote: ({ children }) => (
          <blockquote className="border-s-2 border-current/30 ps-3 italic opacity-90">{children}</blockquote>
        ),
      }}
    >
      {content}
    </ReactMarkdown>
  );
}
