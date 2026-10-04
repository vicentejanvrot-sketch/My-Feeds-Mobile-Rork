// "Update available" banner when the store has a newer version, and a screen
// that blocks the app when this version is below the minimum (app_releases).
// Also saves this phone's version when the app opens. See lib/app-version.ts.
import { useEffect, useState } from "react";
import { AppState, Linking, Modal, Pressable, StyleSheet, Text, View } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Download, X } from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { useAuth } from "@/lib/auth-provider";
import { appVersion, checkForUpdate, reportInstall, type UpdateInfo } from "@/lib/app-version";

const DISMISSED_KEY = "app.updateDismissed";

export function AppUpdateGate() {
  const { user } = useAuth();
  const insets = useSafeAreaInsets();
  const [update, setUpdate] = useState<UpdateInfo | null>(null);
  const [dismissed, setDismissed] = useState<string | null>(null);

  useEffect(() => {
    if (!user) return;
    let cancelled = false;
    const run = () => {
      void reportInstall(user.id);
      void checkForUpdate().then((info) => { if (!cancelled) setUpdate(info); });
    };
    run();
    void AsyncStorage.getItem(DISMISSED_KEY).then((v) => { if (!cancelled) setDismissed(v); }).catch(() => undefined);
    // Back in the app (e.g. after updating elsewhere or a long time away): check again.
    const sub = AppState.addEventListener("change", (state) => { if (state === "active") run(); });
    return () => {
      cancelled = true;
      sub.remove();
    };
  }, [user]);

  if (!user || !update) return null;
  const open = () => void Linking.openURL(update.storeUrl).catch(() => undefined);

  if (update.required) {
    return (
      <Modal visible animationType="fade" onRequestClose={() => undefined}>
        <View style={[styles.blocker, { paddingTop: insets.top + 40, paddingBottom: insets.bottom + 24 }]}>
          <View style={styles.blockerIcon}>
            <Download size={30} color={Colors.accent} />
          </View>
          <Text style={styles.blockerTitle}>Update My Feeds</Text>
          <Text style={styles.blockerText}>
            This version ({appVersion}) is no longer supported. Update to version {update.latestVersion} to keep using My Feeds.
          </Text>
          <Pressable onPress={open} style={({ pressed }) => [styles.primary, pressed && { opacity: 0.8 }]} accessibilityRole="button">
            <Text style={styles.primaryText}>Update now</Text>
          </Pressable>
        </View>
      </Modal>
    );
  }

  // "Later" hides the banner until an even newer version comes out.
  if (dismissed === update.latestVersion) return null;
  const later = () => {
    setDismissed(update.latestVersion);
    void AsyncStorage.setItem(DISMISSED_KEY, update.latestVersion).catch(() => undefined);
  };
  return (
    <View style={[styles.bannerWrap, { top: insets.top + 8 }]} pointerEvents="box-none">
      <View style={styles.banner}>
        <Download size={18} color={Colors.accent} />
        <View style={{ flex: 1 }}>
          <Text style={styles.bannerTitle}>New version available</Text>
          <Text style={styles.bannerText}>Version {update.latestVersion} is ready to install.</Text>
        </View>
        <Pressable onPress={open} style={({ pressed }) => [styles.update, pressed && { opacity: 0.8 }]} accessibilityRole="button">
          <Text style={styles.updateText}>Update</Text>
        </Pressable>
        <Pressable onPress={later} hitSlop={10} accessibilityLabel="Later">
          <X size={18} color={Colors.textMuted} />
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  bannerWrap: { position: "absolute", left: 12, right: 12, zIndex: 1000 },
  banner: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 14,
    backgroundColor: Colors.card,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    shadowColor: "#000",
    shadowOpacity: 0.3,
    shadowRadius: 12,
    shadowOffset: { width: 0, height: 4 },
    elevation: 8,
  },
  bannerTitle: { fontSize: 14, fontWeight: "700", color: Colors.textPrimary },
  bannerText: { fontSize: 12, color: Colors.textSecondary, marginTop: 1 },
  update: { backgroundColor: Colors.accent, paddingHorizontal: 12, paddingVertical: 7, borderRadius: 999 },
  updateText: { color: "#fff", fontSize: 13, fontWeight: "700" },
  blocker: { flex: 1, backgroundColor: Colors.background, alignItems: "center", justifyContent: "center", paddingHorizontal: 28, gap: 14 },
  blockerIcon: { width: 64, height: 64, borderRadius: 32, backgroundColor: Colors.input, alignItems: "center", justifyContent: "center" },
  blockerTitle: { fontSize: 22, fontWeight: "800", color: Colors.textPrimary, textAlign: "center" },
  blockerText: { fontSize: 15, color: Colors.textSecondary, textAlign: "center", lineHeight: 21 },
  primary: { marginTop: 10, backgroundColor: Colors.accent, paddingHorizontal: 28, paddingVertical: 14, borderRadius: 999 },
  primaryText: { color: "#fff", fontSize: 16, fontWeight: "700" },
});
