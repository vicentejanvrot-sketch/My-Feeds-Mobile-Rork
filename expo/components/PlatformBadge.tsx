import { StyleSheet, Text, View } from "react-native";
import { Platform, PLATFORM_META } from "@/lib/platforms";

// Small square badge (YT / X / r/) — same colours as the web app.
export function PlatformBadge({ platform, size = "sm" }: { platform: Platform; size?: "sm" | "md" }) {
  const meta = PLATFORM_META[platform];
  const box = size === "sm" ? styles.sm : styles.md;
  return (
    <View
      style={[styles.base, box, { backgroundColor: meta.bg }]}
      accessibilityLabel={meta.label}
    >
      <Text style={[styles.text, size === "sm" ? styles.textSm : styles.textMd, { color: meta.fg }]}>
        {meta.short}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 6,
  },
  sm: { width: 20, height: 20 },
  md: { width: 28, height: 28, borderRadius: 7 },
  text: { fontWeight: "800" },
  textSm: { fontSize: 9 },
  textMd: { fontSize: 11 },
});
