// Download icon for the post reader and the video player: saves the item on the
// phone for offline use (see lib/downloads.ts). Shows the progress while saving
// and a check once it's saved; tapping the check offers to remove it.
// For a YouTube video it first explains that the video itself can't be saved.
import { useEffect } from "react";
import { Alert, Pressable, StyleSheet, Text, View } from "react-native";
import * as Haptics from "expo-haptics";
import { CircleCheck, Download } from "lucide-react-native";
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
          ? "Episode saved inside My Feeds for offline listening. See it in this app's Settings tab > Downloads."
          : youtubeVideoId
            ? "Summary saved inside My Feeds for offline reading. The video still needs a connection. See it in this app's Settings tab > Downloads."
            : "Saved inside My Feeds for offline reading. See it in this app's Settings tab > Downloads.",
        "success",
      );
    } catch (e) {
      showToast(e instanceof Error ? e.message : "Download failed", "error");
    }
  };

  // YouTube only lets its videos play in its own player, so the video can't be kept on
  // the phone. Say so before saving, and point to YouTube's own Download instead.
  const explainYouTube = () => {
    Alert.alert(
      "This video can't be downloaded",
      "YouTube only lets its videos play in its own player, so My Feeds can't save this video to your phone.\n\n" +
        "Save summary keeps the summary and key moments for offline reading. To watch the video offline, open it in the YouTube app and use Download there (needs YouTube Premium).",
      [
        { text: "Cancel", style: "cancel" },
        {
          text: "Open YouTube",
          onPress: () => {
            openExternalLink(`https://www.youtube.com/watch?v=${youtubeVideoId}`).catch(() =>
              showToast("Couldn't open link", "error"),
            );
          },
        },
        { text: "Save summary", onPress: () => void start() },
      ],
    );
  };

  const remove = () => {
    Alert.alert("Remove download?", "It stays in your feed. Only the copy on this phone is deleted.", [
      { text: "Cancel", style: "cancel" },
      {
        text: "Remove",
        style: "destructive",
        onPress: () => {
          void deleteDownload(itemId).then(() => showToast("Download removed", "success"));
        },
      },
    ]);
  };

  if (progress !== undefined) {
    return (
      <View style={styles.btn} accessibilityLabel={`Downloading, ${Math.round(progress * 100)} percent`}>
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
      accessibilityLabel={saved ? "Downloaded. Remove download" : "Download for offline"}
    >
      {saved ? <CircleCheck size={size} color={Colors.success} /> : <Download size={size} color={Colors.textSecondary} />}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  btn: { minWidth: 44, height: 44, alignItems: "center", justifyContent: "center" },
  percent: { color: Colors.accent, fontSize: 12, fontWeight: "700", fontVariant: ["tabular-nums"] },
});
