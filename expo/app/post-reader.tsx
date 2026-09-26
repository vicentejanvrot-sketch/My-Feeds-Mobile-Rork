// In-app reader for X posts and Reddit threads — the mobile twin of the web
// PostReaderModal, so reading works the same everywhere.
import { useEffect, useState } from "react";
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import { useLocalSearchParams, router } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Image } from "expo-image";
import * as Haptics from "expo-haptics";
import { useQuery } from "@tanstack/react-query";
import { X, ExternalLink, Circle, CheckCircle, Heart, Clock, ThumbsUp, Repeat2, MessageCircle, ArrowBigUp } from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { supabase } from "@/lib/supabase";
import { useUpdateItemStatus } from "@/lib/hooks";
import { useToast } from "@/components/Toast";
import { openExternalLink } from "@/lib/open-link";
import { timeAgo } from "@/lib/format";
import { PlatformBadge } from "@/components/PlatformBadge";
import { PLATFORM_META, platformOf, formatCount } from "@/lib/platforms";
import type { ItemStatus, ItemWithAnalysis } from "@/lib/database";

// Posts are read, not watched: same four statuses, reading-friendly labels.
const POST_STATUSES: { key: ItemStatus; label: string; color: string; Icon: typeof Circle }[] = [
  { key: "not_watched", label: "Unread", color: Colors.textSecondary, Icon: Circle },
  { key: "watched", label: "Read", color: Colors.success, Icon: CheckCircle },
  { key: "liked", label: "Saved", color: Colors.destructive, Icon: Heart },
  { key: "watch_later", label: "Read Later", color: Colors.warning, Icon: Clock },
];

export default function PostReaderScreen() {
  const { itemId } = useLocalSearchParams<{ itemId?: string }>();
  const insets = useSafeAreaInsets();
  const showToast = useToast();
  const updateStatus = useUpdateItemStatus();

  const itemQ = useQuery({
    queryKey: ["postItem", itemId ?? ""],
    enabled: !!itemId,
    queryFn: async (): Promise<ItemWithAnalysis | null> => {
      const { data, error } = await supabase
        .from("items")
        .select("*, item_analysis(*)")
        .eq("id", itemId!)
        .single();
      if (error) throw error;
      return data as ItemWithAnalysis;
    },
  });

  const item = itemQ.data ?? null;
  const [status, setStatus] = useState<ItemStatus>("not_watched");
  useEffect(() => {
    if (item) setStatus((item.user_status ?? "not_watched") as ItemStatus);
  }, [item]);

  const changeStatus = (next: ItemStatus) => {
    if (!item || next === status) return;
    void Haptics.selectionAsync();
    const previous = status;
    setStatus(next);
    updateStatus.mutate(
      { id: item.id, status: next },
      {
        onError: () => {
          setStatus(previous);
          showToast("Couldn't update status", "error");
        },
      },
    );
  };

  if (itemQ.isLoading || !item) {
    return (
      <View style={[styles.screen, styles.center, { paddingTop: insets.top }]}>
        {itemQ.isError ? (
          <Text style={styles.muted}>Couldn't load this post.</Text>
        ) : (
          <ActivityIndicator color={Colors.accent} />
        )}
      </View>
    );
  }

  const platform = platformOf(item.platform);
  const meta = PLATFORM_META[platform];
  const analysis = item.item_analysis?.[0] ?? null;
  const metrics = item.metrics ?? {};
  const image = item.media?.find((m) => m.type !== "video")?.url ?? item.thumbnail_url ?? null;
  const keyPoints = analysis?.key_points ?? [];

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.headerBtn} accessibilityLabel="Close">
          <X size={22} color={Colors.textPrimary} />
        </Pressable>
        <View style={styles.headerMeta}>
          <PlatformBadge platform={platform} />
          <Text style={styles.headerText} numberOfLines={1}>
            {item.channel_name ?? meta.label}
            {item.published_at ? ` · ${timeAgo(item.published_at)}` : ""}
          </Text>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {platform === "reddit" ? <Text style={styles.title}>{item.title}</Text> : null}
        {platform === "reddit" && item.author_handle ? (
          <Text style={styles.muted}>{item.author_handle}</Text>
        ) : null}

        {item.body ? (
          <Text style={platform === "x" ? styles.bodyLarge : styles.body}>{item.body}</Text>
        ) : null}

        {image ? <Image source={{ uri: image }} style={styles.image} contentFit="cover" /> : null}

        <View style={styles.metricsRow}>
          {platform === "x" ? (
            <>
              <Metric icon={<MessageCircle size={14} color={Colors.textMuted} />} value={formatCount(metrics.replies)} />
              <Metric icon={<Repeat2 size={14} color={Colors.textMuted} />} value={formatCount(metrics.reposts)} />
              <Metric icon={<ThumbsUp size={14} color={Colors.textMuted} />} value={formatCount(metrics.likes)} />
            </>
          ) : (
            <>
              <Metric icon={<ArrowBigUp size={15} color={Colors.textMuted} />} value={formatCount(metrics.score)} />
              <Metric icon={<MessageCircle size={14} color={Colors.textMuted} />} value={`${formatCount(metrics.comments)} comments`} />
            </>
          )}
        </View>

        {analysis?.short_summary || keyPoints.length > 0 ? (
          <View style={styles.summaryBox}>
            <Text style={styles.summaryLabel}>{platform === "reddit" ? "THREAD SUMMARY" : "SUMMARY"}</Text>
            {analysis?.short_summary ? <Text style={styles.summaryText}>{analysis.short_summary}</Text> : null}
            {keyPoints.map((p) => (
              <Text key={p} style={styles.summaryPoint}>• {p}</Text>
            ))}
          </View>
        ) : null}
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: Math.max(insets.bottom, 12) }]}>
        <View style={styles.statusRow}>
          {POST_STATUSES.map(({ key, label, color, Icon }) => {
            const active = status === key;
            return (
              <Pressable
                key={key}
                onPress={() => changeStatus(key)}
                style={({ pressed }) => [styles.statusBtn, active && styles.statusBtnActive, pressed && { opacity: 0.7 }]}
                accessibilityRole="button"
                accessibilityState={{ selected: active }}
              >
                <Icon size={16} color={color} fill={key === "liked" && active ? color : "transparent"} />
                <Text style={styles.statusText}>{label}</Text>
              </Pressable>
            );
          })}
        </View>
        <Pressable
          onPress={() => openExternalLink(item.url)}
          style={({ pressed }) => [styles.openBtn, pressed && { opacity: 0.7 }]}
          accessibilityRole="link"
        >
          <ExternalLink size={16} color={Colors.textPrimary} />
          <Text style={styles.openText}>{meta.openLabel}</Text>
        </Pressable>
      </View>
    </View>
  );
}

function Metric({ icon, value }: { icon: React.ReactNode; value: string }) {
  return (
    <View style={styles.metric}>
      {icon}
      <Text style={styles.metricText}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.background },
  center: { alignItems: "center", justifyContent: "center" },
  header: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.border,
  },
  headerBtn: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  headerMeta: { flex: 1, flexDirection: "row", alignItems: "center", gap: 8 },
  headerText: { flex: 1, color: Colors.textSecondary, fontSize: 13, fontWeight: "600" },
  content: { padding: 16, gap: 14 },
  title: { color: Colors.textPrimary, fontSize: 19, fontWeight: "800", lineHeight: 25 },
  body: { color: Colors.textPrimary, fontSize: 15, lineHeight: 23 },
  bodyLarge: { color: Colors.textPrimary, fontSize: 17, lineHeight: 26 },
  muted: { color: Colors.textSecondary, fontSize: 13 },
  image: { width: "100%", aspectRatio: 16 / 9, borderRadius: 12, backgroundColor: Colors.card },
  metricsRow: { flexDirection: "row", gap: 18 },
  metric: { flexDirection: "row", alignItems: "center", gap: 5 },
  metricText: { color: Colors.textSecondary, fontSize: 13, fontWeight: "600" },
  summaryBox: {
    backgroundColor: "rgba(14, 165, 233, 0.10)",
    borderColor: "rgba(14, 165, 233, 0.25)",
    borderWidth: 1,
    borderRadius: 12,
    padding: 12,
    gap: 6,
  },
  summaryLabel: { color: Colors.accent, fontSize: 11, fontWeight: "800", letterSpacing: 0.8 },
  summaryText: { color: Colors.textPrimary, fontSize: 14, lineHeight: 21 },
  summaryPoint: { color: Colors.textPrimary, fontSize: 14, lineHeight: 21 },
  footer: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingHorizontal: 12,
    paddingTop: 10,
    gap: 10,
    backgroundColor: Colors.card,
  },
  statusRow: { flexDirection: "row", gap: 6 },
  statusBtn: {
    flex: 1,
    minHeight: 48,
    alignItems: "center",
    justifyContent: "center",
    gap: 4,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  statusBtnActive: { borderColor: Colors.accent, backgroundColor: "rgba(14, 165, 233, 0.10)" },
  statusText: { color: Colors.textPrimary, fontSize: 11, fontWeight: "600" },
  openBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    height: 44,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  openText: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700" },
});
