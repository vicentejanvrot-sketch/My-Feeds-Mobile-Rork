import { StyleSheet, Text, View } from "react-native";
import { Colors } from "@/constants/colors";
import type { ChannelStatus } from "@/lib/database";
import { useTranslation } from "react-i18next";
import i18n from "@/lib/i18n";

const CONFIG: Record<ChannelStatus, { label: string; color: string }> = {
  not_watched: { label: "New", color: Colors.textMuted },
  watched: { label: "Seen", color: Colors.success },
  liked: { label: "Liked", color: Colors.destructive },
  watch_later: { label: "Later", color: Colors.warning },
};

/** Convert an HSL color string to HSLA with a given alpha. */
function hsla(hsl: string, alpha: number): string {
  return hsl.replace(/^hsl\(/, "hsla(").replace(/\)$/, `, ${alpha})`);
}

export const CHANNEL_STATUS_FILTERS = [
  { key: "all", label: "All Channels" },
  { key: "not_watched", label: "New" },
  { key: "watched", label: "Seen" },
  { key: "liked", label: "Liked" },
  { key: "watch_later", label: "Later" },
] as const;

export type ChannelFilterKey = (typeof CHANNEL_STATUS_FILTERS)[number]["key"];

/** Filter label in the active language ("New" / "Novos"). */
export function channelFilterLabel(key: ChannelFilterKey): string {
  return i18n.t(`channelFilter.${key}` as const);
}

export function ChannelStatusPill({ status }: { status: ChannelStatus | null }) {
  const cfg = (status && CONFIG[status]) ? CONFIG[status] : CONFIG.not_watched;
  const { t } = useTranslation();
  return (
    <View style={[styles.pill, { backgroundColor: hsla(cfg.color, 0.15), borderColor: cfg.color, borderWidth: 1 }]}>
      <View style={[styles.dot, { backgroundColor: cfg.color }]} />
      <Text style={[styles.label, { color: cfg.color }]}>
        {t(`itemStatus.${status && CONFIG[status] ? status : "not_watched"}` as const)}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  pill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 5,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 999,
    alignSelf: "flex-start",
  },
  dot: { width: 6, height: 6, borderRadius: 3 },
  label: { fontSize: 11, fontWeight: "600" as const },
});
