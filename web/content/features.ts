import {
  FolderSimple,
  ChatCircleDots,
  Fingerprint,
  UsersThree,
  QrCode,
  WhatsappLogo,
  ChartLineUp,
  FirstAidKit,
  Pill,
} from "@phosphor-icons/react/dist/ssr";

// Only the icon and a stable message key live here - the human-readable
// title/description for each feature come from the "features.items.*" keys in
// messages/{locale}.json so the grid renders in the active marketing locale.
export const productFeatures = [
  { key: "organize", icon: FolderSimple },
  { key: "assistant", icon: ChatCircleDots },
  { key: "personalized", icon: Fingerprint },
  { key: "family", icon: UsersThree },
  { key: "sharing", icon: QrCode },
  { key: "whatsapp", icon: WhatsappLogo },
  { key: "analytics", icon: ChartLineUp },
  { key: "emergency", icon: FirstAidKit },
  { key: "reminders", icon: Pill },
] as const;
