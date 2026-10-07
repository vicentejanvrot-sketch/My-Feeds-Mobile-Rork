// Download icon for the post reader and the video player: saves the item on the
// phone for offline use (see lib/downloads.ts). Shows the progress while saving
// and a check once it's saved; tapping the check offers to remove it.
// For a YouTube video it first explains that the video itself can't be saved.
import { useEffect } from "react";
import { Alert, Pressable, StyleSheet, Text, View } from "react-native";
import * as Haptics from "expo-haptics";
import { CircleCheck, Download } from "lucide-react-native";
import { useTranslation } from "react-i18next";
import { Colors } from "@/constants/colors";
import { useToast } from "@/components/Toast";
import { openExternalLink } from "@/lib/open-link";
import { deleteDownload, downloadItem, downloadsSupported, loadDownloads, useDownloadsStore } from "@/lib/downloads";

export function DownloadButton({
  itemId,
  hasAudio,
  youtubeVideoId,
  size = 20,
}: {
  itemId: string;
  hasAudio?: boolean;
  /** Set for YouTube videos: the video can't be downloaded, only its summary. */
  youtubeVideoId?: string | null;
  size?: number;
}) {
  const showToast = useToast();
  const { t } = useTranslation();
  const saved = useDownloadsStore((s) => !!s.entries[itemId]);
  const progress = useDownloadsStore((s) => s.progress[itemId]);

  useEffect(() => {
    void loadDownloads();
  }, []);

  if (!downloadsSupported) return null;

  const start = async () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    try {
      await downloadItem(itemId);
      // Downloads stay inside My Feeds (not Photos or Files), so say where to find them.
      showToast(
        hasAudio
          ? t("downloads.savedEpisode")
          : youtubeVideoId
            ? t("downloads.savedSummary")
            : t("downloads.savedItem"),
        "success",
      );
    } catch (e) {
      showToast(e instanceof Error ? e.message : t("downloads.failed"), "error");
    }
  };

  // YouTube only lets its videos play in its own player, so the video can't be kept on
  // the phone. Say so before saving, and point to YouTube's own Download instead.
  const explainYouTube = () => {
    Alert.alert(
      t("downloads.youtubeTitle"),
      t("downloads.youtubeBody1") + "\n\n" + t("downloads.youtubeBody2"),
      [
        { text: t("common.cancel"), style: "cancel" },
        {
          text: t("downloads.openYouTube"),
          onPress: () => {
            openExternalLink(`https://www.youtube.com/watch?v=${youtubeVideoId}`).catch(() =>
              showToast(t("player.openLinkFailed"), "error"),
            );
          },
        },
        { text: t("downloads.saveSummary"), onPress: () => void start() },
      ],
    );
  };

  const remove = () => {
    Alert.alert(t("downloads.removeTitle"), t("downloads.removeBody"), [
      { text: t("common.cancel"), style: "cancel" },
      {
        text: t("agentDetail.remove"),
        style: "destructive",
        onPress: () => {
          void deleteDownload(itemId).then(() => showToast(t("downloads.removed"), "success"));
        },
      },
    ]);
  };

  if (progress !== undefined) {
    return (
      <View style={styles.btn} accessibilityLabel={t("downloads.progressLabel", { percent: Math.round(progress * 100) })}>
        <Text style={styles.percent}>{Math.round(progress * 100)}%</Text>
      </View>
    );
  }

  return (
    <Pressable
      onPress={saved ? remove : youtubeVideoId ? explainYouTube : () => void start()}
      hitSlop={10}
      style={({ pressed }) => [styles.btn, pressed && { opacity: 0.6 }]}
      accessibilityRole="button"
      accessibilityLabel={saved ? t("downloads.savedLabel") : t("downloads.downloadLabel")}
    >
      {saved ? <CircleCheck size={size} color={Colors.success} /> : <Download size={size} color={Colors.textSecondary} />}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  btn: { minWidth: 44, height: 44, alignItems: "center", justifyContent: "center" },
  percent: { color: Colors.accent, fontSize: 12, fontWeight: "700", fontVariant: ["tabular-nums"] },
});
