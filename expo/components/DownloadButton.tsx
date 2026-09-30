// Download icon for the post reader and the video player: saves the item on the
// phone for offline use (see lib/downloads.ts). Shows the progress while saving
// and a check once it's saved; tapping the check offers to remove it.
import { useEffect } from "react";
import { Alert, Pressable, StyleSheet, Text, View } from "react-native";
import * as Haptics from "expo-haptics";
import { CircleCheck, Download } from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { useToast } from "@/components/Toast";
import { deleteDownload, downloadItem, downloadsSupported, loadDownloads, useDownloadsStore } from "@/lib/downloads";

export function DownloadButton({ itemId, hasAudio, size = 20 }: { itemId: string; hasAudio?: boolean; size?: number }) {
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
      showToast(hasAudio ? "Episode saved for offline listening" : "Saved for offline reading", "success");
    } catch (e) {
      showToast(e instanceof Error ? e.message : "Download failed", "error");
    }
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
      onPress={saved ? remove : () => void start()}
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
