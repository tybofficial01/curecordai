import { Tooth, Eye, Heart, Pill, FolderSimple, Brain, Bone } from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";

// Mirrors fe/lib/features/records/screens/records_screen.dart - same icon keys, same 5 choices
// offered in the create-folder sheet (in this order), plus 2 extra keys kept only for rendering
// folders that already carry them (not offered as new picks, matching the mobile app).
export const FOLDER_ICON_OPTIONS: { key: string; icon: Icon; label: string }[] = [
  { key: "dental", icon: Tooth, label: "Dental" },
  { key: "eye", icon: Eye, label: "Eye" },
  { key: "heart", icon: Heart, label: "Heart" },
  { key: "medicine", icon: Pill, label: "Medicine" },
  { key: "folder", icon: FolderSimple, label: "General" },
];

export const FOLDER_ICON_MAP: Record<string, Icon> = {
  dental: Tooth,
  eye: Eye,
  heart: Heart,
  medicine: Pill,
  folder: FolderSimple,
  neurology: Brain,
  orthopedics: Bone,
};

export function folderIconFor(key: string | null | undefined): Icon {
  return (key && FOLDER_ICON_MAP[key]) || FolderSimple;
}
