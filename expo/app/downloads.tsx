// Everything saved on this phone for offline use, newest first. Works with no
// connection: the list and the files are read from the phone. Remove one item
// with the trash icon, or everything with "Delete all".
import { useEffect, useMemo } from "react";
import { useTranslation } from "react-i18next";
import { Alert, FlatList, Pressable, StyleSheet, Text, View } from "react-native";
import { router } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Image } from "expo-image";
import { ChevronLeft, Download, Headphones, Trash2 } from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { useToast } from "@/components/Toast";
import { PlatformBadge } from "@/components/PlatformBadge";
import { platformOf } from "@/lib/platforms";
import { timeAgo } from "@/lib/format";
import {
  deleteAllDownloads,
  deleteDownload,
  downloadsSupported,
  formatBytes,
  loadDownloads,
  localFileUri,
  useDownloadsStore,
  type DownloadEntry,
} from "@/lib/downloads";

export default function DownloadsScreen() {
  const insets = useSafeAreaInsets();
  const showToast = useToast();
  const { t } = useTranslation();
  const loaded = useDownloadsStore((s) => s.loaded);
  const entries = useDownloadsStore((s) => s.entries);

  useEffect(() => {
    void loadDownloads();
  }, []);

  const list = useMemo(
    () => Object.values(entries).sort((a, b) => b.savedAt.localeCompare(a.savedAt)),
    [entries],
  );
  const totalBytes = list.reduce((sum, e) => sum + e.bytes, 0);

  const removeOne = (entry: DownloadEntry) => {
    Alert.alert(t("downloads.removeTitle"), entry.title ?? t("downloads.thisItem"), [
      { text: t("common.cancel"), style: "cancel" },
      {
        text: t("agentDetail.remove"),
        style: "destructive",
        onPress: () => void deleteDownload(entry.itemId).then(() => showToast(t("downloads.removed"), "success")),
      },
    ]);
  };

  const removeAll = () => {
    Alert.alert(t("downloads.deleteAllTitle"), t("downloads.deleteAllBody", { size: formatBytes(totalBytes) }), [
      { text: t("common.cancel"), style: "cancel" },
      {
        text: t("history.deleteAll"),
        style: "destructive",
        onPress: () => void deleteAllDownloads().then(() => showToast(t("downloads.allDeleted"), "success")),
      },
    ]);
  };

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.headerBtn} accessibilityLabel={t("common.back")}>
          <ChevronLeft size={24} color={Colors.textPrimary} />
        </Pressable>
        <Text style={styles.headerTitle}>{t("settings.downloads")}</Text>
        {list.length > 0 ? (
          <Pressable onPress={removeAll} hitSlop={8} style={styles.deleteAll} accessibilityRole="button">
            <Text style={styles.deleteAllText}>{t("history.deleteAll")}</Text>
          </Pressable>
        ) : (
          <View style={styles.headerBtn} />
        )}
      </View>

      {!downloadsSupported ? (
        <View style={styles.empty}>
          <Text style={styles.emptyText}>{t("downloads.unsupported")}</Text>
        </View>
      ) : loaded && list.length === 0 ? (
        <View style={styles.empty}>
          <Download size={36} color={Colors.textMuted} />
          <Text style={styles.emptyTitle}>{t("downloads.emptyTitle")}</Text>
          <Text style={styles.emptyText}>{t("downloads.emptyBody")}</Text>
        </View>
      ) : (
        <FlatList
          data={list}
          keyExtractor={(e) => e.itemId}
          contentContainerStyle={{ padding: 16, gap: 10, paddingBottom: insets.bottom + 24 }}
          ListHeaderComponent={
            <Text style={styles.summary}>
              {t("downloads.summary", { count: list.length, size: formatBytes(totalBytes) })}
            </Text>
          }
          renderItem={({ item: entry }) => (
            <Pressable
              onPress={() => router.push(`/post-reader?itemId=${encodeURIComponent(entry.itemId)}`)}
              style={({ pressed }) => [styles.row, pressed && { opacity: 0.7 }]}
              accessibilityRole="button"
            >
              {entry.thumbFile ? (
                <Image source={{ uri: localFileUri(entry.itemId, entry.thumbFile) }} style={styles.thumb} contentFit="cover" />
              ) : (
                <View style={[styles.thumb, styles.thumbEmpty]}>
                  <PlatformBadge platform={platformOf(entry.platform)} />
                </View>
              )}
              <View style={{ flex: 1, gap: 4 }}>
                <Text style={styles.title} numberOfLines={2}>{entry.title ?? t("feed.untitled")}</Text>
                <View style={styles.metaRow}>
                  <PlatformBadge platform={platformOf(entry.platform)} />
                  {entry.hasAudio ? <Headphones size={13} color={Colors.textSecondary} /> : null}
                  <Text style={styles.meta} numberOfLines={1}>
                    {entry.channelName ? `${entry.channelName} · ` : ""}
                    {t("downloads.sizeSaved", { size: formatBytes(entry.bytes), when: timeAgo(entry.savedAt) })}
                  </Text>
                </View>
              </View>
              <Pressable
                onPress={() => removeOne(entry)}
                hitSlop={8}
                style={styles.trash}
                accessibilityRole="button"
                accessibilityLabel={t("downloads.removeLabel")}
              >
                <Trash2 size={18} color={Colors.textSecondary} />
              </Pressable>
            </Pressable>
          )}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.background },
  header: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 8,
    paddingVertical: 6,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.border,
  },
  headerBtn: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  headerTitle: { flex: 1, color: Colors.textPrimary, fontSize: 17, fontWeight: "700" },
  deleteAll: { height: 44, paddingHorizontal: 10, justifyContent: "center" },
  deleteAllText: { color: Colors.destructive, fontSize: 14, fontWeight: "700" },
  summary: { color: Colors.textSecondary, fontSize: 13, lineHeight: 19, marginBottom: 4 },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    padding: 10,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: Colors.border,
    backgroundColor: Colors.card,
  },
  thumb: { width: 64, height: 64, borderRadius: 8, backgroundColor: Colors.input },
  thumbEmpty: { alignItems: "center", justifyContent: "center" },
  title: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700", lineHeight: 19 },
  metaRow: { flexDirection: "row", alignItems: "center", gap: 6 },
  meta: { flex: 1, color: Colors.textSecondary, fontSize: 12 },
  trash: { width: 40, height: 44, alignItems: "center", justifyContent: "center" },
  empty: { flex: 1, alignItems: "center", justifyContent: "center", padding: 32, gap: 10 },
  emptyTitle: { color: Colors.textPrimary, fontSize: 16, fontWeight: "700" },
  emptyText: { color: Colors.textSecondary, fontSize: 14, lineHeight: 20, textAlign: "center" },
});
