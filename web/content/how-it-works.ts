import { UploadSimple, ChatCircleDots, ShareNetwork } from "@phosphor-icons/react/dist/ssr";

// Icon + stable message key only; the step title/description are translated
// under "howItWorks.steps.*" in messages/{locale}.json.
export const howItWorksSteps = [
  { key: "upload", step: "1", icon: UploadSimple },
  { key: "ask", step: "2", icon: ChatCircleDots },
  { key: "share", step: "3", icon: ShareNetwork },
] as const;
