// In-app reader for X, Reddit, Instagram and LinkedIn posts — the mobile twin of the web
// PostReaderModal, so reading works the same everywhere.
import { useEffect, useState } from "react";
import { ActivityIndicator, Platform as RNPlatform, Pressable, ScrollView, Share, StyleSheet, Text, View, useWindowDimensions } from "react-native";
import { WebView } from "react-native-webview";
import { useLocalSearchParams, router } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Image } from "expo-image";
import * as Haptics from "expo-haptics";
import { useQuery } from "@tanstack/react-query";
import {
  X,
  ExternalLink,
  Heart,
  Repeat2,
  MessageCircle,
  MessageSquare,
  BadgeCheck,
  Bookmark,
  Share as ShareIcon,
  ArrowBigUp,
  ArrowBigDown,
  Check,
  Send,
  ThumbsUp,
} from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { supabase } from "@/lib/supabase";
import { useUpdateItemStatus } from "@/lib/hooks";
import { useToast } from "@/components/Toast";
import { openExternalLink } from "@/lib/open-link";
import { timeAgo } from "@/lib/format";
import { PlatformBadge } from "@/components/PlatformBadge";
import { PLATFORM_META, platformOf, formatCount } from "@/lib/platforms";
import type { ItemStatus, ItemWithAnalysis } from "@/lib/database";

// The action bar copies each platform's own row under a post. In My Feeds:
// Like / Upvote = Saved, Bookmark / Save = Read Later, the check = Read.
// Reply and Repost open the post on X, since those happen on the platform.
const X_PINK = "#F91880";
const X_BLUE = "#1D9BF0";
const REDDIT_ORANGE = "#FF4500";
const IG_RED = "#FF3040";
const LINKEDIN_BLUE = "#378FE9";

type PostMetrics = {
  likes?: number;
  reposts?: number;
  replies?: number;
  views?: number;
  plays?: number;
  bookmarks?: number;
  quotes?: number;
  score?: number;
  comments?: number;
};

// An image, or a quoted post / X article (type "quote" / "article").
type PostEmbed = {
  type: string;
  url: string;
  author_name?: string;
  author_handle?: string;
  author_avatar?: string | null;
  verified?: boolean;
  created_at?: string | null;
  text?: string;
  image?: string | null;
  title?: string | null;
  preview?: string | null;
  // Playable video: MP4, and an HLS stream (plays with sound on iOS).
  video_url?: string | null;
  hls_url?: string | null;
};

function escapeAttr(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
}

// Instagram videos are stored behind our media-proxy, but the CDN plays them
// fine straight from Instagram as long as no Referer is sent. Going direct
// avoids the extra hop on every chunk, which made playback pause after the
// first second. The proxied link stays as a fallback.
function directVideoUrl(url: string | null | undefined): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    if (!parsed.pathname.endsWith("/functions/v1/media-proxy")) return null;
    const inner = new URL(parsed.searchParams.get("u") ?? "");
    const host = inner.hostname.toLowerCase();
    return host.endsWith(".cdninstagram.com") || host.endsWith(".fbcdn.net") ? inner.toString() : null;
  } catch {
    return null;
  }
}

// Plays a post's video in place, like on X and Reddit. iOS plays the HLS
// stream; Android gets the MP4. No Referer is sent: X's video server
// refuses requests that carry another site's address.
function PostVideo({ media }: { media: PostEmbed }) {
  const main =
    (RNPlatform.OS === "ios" ? media.hls_url || media.video_url : media.video_url || media.hls_url) || "";
  if (!main) return null;
  const direct = directVideoUrl(media.video_url);
  const sources = (direct ? [direct, main] : [main])
    .map((src) => `<source src="${escapeAttr(src)}">`)
    .join("");
  const poster = media.url || media.image || "";
  const html = `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><meta name="referrer" content="no-referrer">
<style>html,body{margin:0;padding:0;background:#000;height:100%}video{width:100%;height:100%;object-fit:contain;background:#000}</style></head>
<body><video${poster ? ` poster="${escapeAttr(poster)}"` : ""} controls playsinline webkit-playsinline preload="auto">${sources}</video></body></html>`;
  return (
    <View style={styles.video}>
      <WebView
        source={{ html }}
        originWhitelist={["*"]}
        allowsInlineMediaPlayback
        mediaPlaybackRequiresUserAction
        allowsFullscreenVideo
        scrollEnabled={false}
        style={styles.videoWeb}
      />
    </View>
  );
}

function formatPostDate(iso: string): string {
  const d = new Date(iso);
  const time = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const date = d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  return `${time} · ${date}`;
}

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
  const xPostId = item.video_id?.startsWith("x:") ? item.video_id.slice(2) : null;
  const liked = status === "liked";
  const bookmarked = status === "watch_later";
  const read = status === "watched";

  const share = () => {
    if (!item.url) return;
    void Share.share({ message: item.url, url: item.url });
  };
  const meta = PLATFORM_META[platform];
  const analysis = item.item_analysis?.[0] ?? null;
  const metrics = (item.metrics ?? {}) as PostMetrics;
  const embeds = (item.media ?? []) as PostEmbed[];
  const quote = embeds.find((m) => m.type === "quote" || m.type === "article") ?? null;
  const video = embeds.find((m) => m.type !== "quote" && m.type !== "article" && (m.video_url || m.hls_url)) ?? null;
  // Carousels (Instagram, LinkedIn) swipe through every photo.
  const photos = embeds.filter((m) => m.type !== "video" && m.type !== "quote" && m.type !== "article" && !!m.url);
  const image =
    photos[0]?.url ??
    (!quote ? item.thumbnail_url : null) ??
    null;
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
          <Text style={platform === "reddit" ? styles.body : styles.bodyLarge}>{item.body}</Text>
        ) : null}

        {video ? (
          <PostVideo media={video} />
        ) : photos.length > 1 ? (
          <PhotoCarousel urls={photos.map((p) => p.url)} />
        ) : image ? (
          <Image source={{ uri: image }} style={styles.image} contentFit="cover" />
        ) : null}

        {quote ? <QuoteCard quote={quote} /> : null}

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
        {platform !== "reddit" && item.published_at ? (
          <Text style={styles.dateLine}>
            {platform === "x" ? formatPostDate(item.published_at) : formatPostDate(item.published_at).split(" · ")[1]}
            {metrics.views || metrics.plays ? (
              <>
                {" · "}
                <Text style={styles.dateLineStrong}>{formatCount(metrics.views || metrics.plays)}</Text> Views
              </>
            ) : null}
          </Text>
        ) : null}
        {platform === "instagram" ? (
          // Instagram: like, comment, share on the left; save on the right.
          <View style={styles.xBar}>
            <View style={styles.xBarEnd}>
              <BarButton
                label={liked ? "Remove from Saved" : "Like (save in My Feeds)"}
                selected={liked}
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                icon={<Heart size={22} color={liked ? IG_RED : Colors.textPrimary} fill={liked ? IG_RED : "transparent"} />}
                value={formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}
              />
              <BarButton
                label="Comment on Instagram"
                onPress={() => openExternalLink(item.url)}
                icon={<MessageCircle size={22} color={Colors.textPrimary} style={{ transform: [{ scaleX: -1 }] }} />}
                value={formatCount(metrics.comments)}
              />
              <BarButton label="Share" onPress={share} icon={<Send size={21} color={Colors.textPrimary} />} />
            </View>
            <BarButton
              label={bookmarked ? "Remove from Read Later" : "Save (Read Later)"}
              selected={bookmarked}
              onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
              icon={<Bookmark size={22} color={Colors.textPrimary} fill={bookmarked ? Colors.textPrimary : "transparent"} />}
            />
          </View>
        ) : platform === "linkedin" ? (
          // LinkedIn: Like, Comment, Repost, Send, plus Save.
          <View style={{ gap: 6 }}>
            <View style={styles.liCounts}>
              <View style={styles.liLikeDot}>
                <ThumbsUp size={9} color="#FFFFFF" fill="#FFFFFF" />
              </View>
              <Text style={styles.barText}>{formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}</Text>
              <Text style={[styles.barText, { marginLeft: "auto" }]}>
                {formatCount(metrics.comments)} comments · {formatCount(metrics.reposts)} reposts
              </Text>
            </View>
            <View style={styles.liBar}>
              <LinkedInAction
                label="Like"
                active={liked}
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                icon={<ThumbsUp size={19} color={liked ? LINKEDIN_BLUE : Colors.textSecondary} fill={liked ? LINKEDIN_BLUE : "transparent"} />}
              />
              <LinkedInAction label="Comment" onPress={() => openExternalLink(item.url)} icon={<MessageSquare size={19} color={Colors.textSecondary} />} />
              <LinkedInAction label="Repost" onPress={() => openExternalLink(item.url)} icon={<Repeat2 size={19} color={Colors.textSecondary} />} />
              <LinkedInAction label="Send" onPress={share} icon={<Send size={19} color={Colors.textSecondary} />} />
              <LinkedInAction
                label="Save"
                active={bookmarked}
                onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
                icon={<Bookmark size={19} color={bookmarked ? LINKEDIN_BLUE : Colors.textSecondary} fill={bookmarked ? LINKEDIN_BLUE : "transparent"} />}
              />
            </View>
          </View>
        ) : platform === "x" ? (
          <View style={styles.xBar}>
            <BarButton
              label="Reply on X"
              onPress={xPostId ? () => openExternalLink(`https://x.com/intent/post?in_reply_to=${xPostId}`) : undefined}
              icon={<MessageCircle size={19} color={Colors.textSecondary} />}
              value={formatCount(metrics.replies)}
            />
            <BarButton
              label="Repost on X"
              onPress={xPostId ? () => openExternalLink(`https://x.com/intent/retweet?tweet_id=${xPostId}`) : undefined}
              icon={<Repeat2 size={19} color={Colors.textSecondary} />}
              value={formatCount(metrics.reposts)}
            />
            <BarButton
              label={liked ? "Remove from Saved" : "Like (save in My Feeds)"}
              selected={liked}
              onPress={() => changeStatus(liked ? "watched" : "liked")}
              icon={<Heart size={19} color={liked ? X_PINK : Colors.textSecondary} fill={liked ? X_PINK : "transparent"} />}
              value={formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}
              valueColor={liked ? X_PINK : undefined}
            />
            <BarButton
              label={bookmarked ? "Remove from Read Later" : "Bookmark (Read Later)"}
              selected={bookmarked}
              onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
              icon={<Bookmark size={19} color={bookmarked ? X_BLUE : Colors.textSecondary} fill={bookmarked ? X_BLUE : "transparent"} />}
              value={formatCount((metrics.bookmarks ?? 0) + (bookmarked ? 1 : 0))}
              valueColor={bookmarked ? X_BLUE : undefined}
            />
            <BarButton label="Share" onPress={share} icon={<ShareIcon size={19} color={Colors.textSecondary} />} />
          </View>
        ) : (
          <View style={styles.redditBar}>
            <View style={[styles.votePill, liked && { backgroundColor: REDDIT_ORANGE }]}>
              <Pressable
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                style={styles.voteBtn}
                hitSlop={4}
                accessibilityRole="button"
                accessibilityLabel={liked ? "Remove upvote (Saved)" : "Upvote (save in My Feeds)"}
                accessibilityState={{ selected: liked }}
              >
                <ArrowBigUp size={22} color={liked ? "#FFFFFF" : Colors.textSecondary} fill={liked ? "#FFFFFF" : "transparent"} />
              </Pressable>
              <Text style={[styles.voteText, liked && { color: "#FFFFFF" }]}>
                {formatCount((metrics.score ?? 0) + (liked ? 1 : 0))}
              </Text>
              <Pressable
                onPress={() => changeStatus("watched")}
                style={styles.voteBtn}
                hitSlop={4}
                accessibilityRole="button"
                accessibilityLabel="Downvote (mark as read)"
              >
                <ArrowBigDown size={22} color={liked ? "#FFFFFF" : Colors.textSecondary} />
              </Pressable>
            </View>
            <Pressable
              onPress={() => openExternalLink(item.url)}
              style={styles.redditPill}
              accessibilityRole="button"
              accessibilityLabel="Open comments on Reddit"
            >
              <MessageSquare size={18} color={Colors.textPrimary} />
              <Text style={styles.redditPillText}>{formatCount(metrics.comments)}</Text>
            </Pressable>
            <Pressable
              onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
              style={styles.redditPill}
              accessibilityRole="button"
              accessibilityLabel={bookmarked ? "Unsave (Read Later)" : "Save (Read Later)"}
              accessibilityState={{ selected: bookmarked }}
            >
              <Bookmark size={18} color={bookmarked ? X_BLUE : Colors.textPrimary} fill={bookmarked ? X_BLUE : "transparent"} />
              <Text style={[styles.redditPillText, bookmarked && { color: X_BLUE }]}>{bookmarked ? "Saved" : "Save"}</Text>
            </Pressable>
            <Pressable onPress={share} style={styles.redditPill} accessibilityRole="button" accessibilityLabel="Share">
              <ShareIcon size={18} color={Colors.textPrimary} />
              <Text style={styles.redditPillText}>Share</Text>
            </Pressable>
          </View>
        )}

        <View style={styles.bottomRow}>
          <Pressable
            onPress={() => changeStatus(read ? "not_watched" : "watched")}
            style={({ pressed }) => [styles.openBtn, styles.bottomBtn, read && { borderColor: Colors.success }, pressed && { opacity: 0.7 }]}
            accessibilityRole="button"
            accessibilityState={{ selected: read }}
          >
            <Check size={16} color={read ? Colors.success : Colors.textPrimary} />
            <Text style={[styles.openText, read && { color: Colors.success }]}>{read ? "Read" : "Mark as read"}</Text>
          </Pressable>
          <Pressable
            onPress={() => openExternalLink(item.url)}
            style={({ pressed }) => [styles.openBtn, styles.bottomBtn, pressed && { opacity: 0.7 }]}
            accessibilityRole="link"
          >
            <ExternalLink size={16} color={Colors.textPrimary} />
            <Text style={styles.openText}>{meta.openLabel}</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

// Quoted post or X article, shown as a card inside the post like on X.
function QuoteCard({ quote }: { quote: PostEmbed }) {
  const isArticle = quote.type === "article";
  return (
    <Pressable
      onPress={() => openExternalLink(quote.url)}
      style={({ pressed }) => [styles.quoteCard, pressed && { opacity: 0.8 }]}
      accessibilityRole="link"
    >
      <View style={styles.quoteHeader}>
        {quote.author_avatar ? <Image source={{ uri: quote.author_avatar }} style={styles.quoteAvatar} /> : null}
        <Text style={styles.quoteName} numberOfLines={1}>{quote.author_name}</Text>
        {quote.verified ? <BadgeCheck size={15} color={X_BLUE} /> : null}
        <Text style={styles.quoteHandle} numberOfLines={1}>
          {quote.author_handle}
          {quote.created_at ? ` · ${timeAgo(quote.created_at)}` : ""}
        </Text>
      </View>
      {!isArticle && quote.text ? <Text style={styles.quoteText}>{quote.text}</Text> : null}
      {quote.video_url || quote.hls_url ? (
        <PostVideo media={{ ...quote, url: quote.image || "" }} />
      ) : quote.image ? (
        <Image source={{ uri: quote.image }} style={styles.quoteImage} contentFit="cover" />
      ) : null}
      {isArticle && quote.title ? <Text style={styles.quoteTitle}>{quote.title}</Text> : null}
      {isArticle && quote.preview ? (
        <Text style={styles.quoteText} numberOfLines={3}>{quote.preview}</Text>
      ) : null}
    </Pressable>
  );
}

// Swipeable row of photos for Instagram and LinkedIn carousels.
function PhotoCarousel({ urls }: { urls: string[] }) {
  const { width } = useWindowDimensions();
  const pageWidth = Math.min(width, 720) - 32;
  const [page, setPage] = useState(0);
  return (
    <View style={{ gap: 6 }}>
      <ScrollView
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / pageWidth))}
        style={{ width: pageWidth, borderRadius: 12 }}
      >
        {urls.map((u) => (
          <Image key={u} source={{ uri: u }} style={{ width: pageWidth, aspectRatio: 1, backgroundColor: Colors.card }} contentFit="cover" />
        ))}
      </ScrollView>
      <View style={styles.dots}>
        {urls.map((u, i) => (
          <View key={u} style={[styles.dot, i === page && styles.dotActive]} />
        ))}
      </View>
    </View>
  );
}

function LinkedInAction({ label, icon, active, onPress }: { label: string; icon: React.ReactNode; active?: boolean; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.liAction, pressed && { opacity: 0.6 }]}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ selected: !!active }}
    >
      {icon}
      <Text style={[styles.liActionText, active && { color: LINKEDIN_BLUE }]}>{label}</Text>
    </Pressable>
  );
}

function BarButton({
  label,
  icon,
  value,
  valueColor,
  selected,
  onPress,
}: {
  label: string;
  icon: React.ReactNode;
  value?: string;
  valueColor?: string;
  selected?: boolean;
  onPress?: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress}
      style={({ pressed }) => [styles.barBtn, pressed && { opacity: 0.6 }]}
      hitSlop={4}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ selected: !!selected }}
    >
      {icon}
      {value !== undefined ? <Text style={[styles.barText, valueColor ? { color: valueColor } : null]}>{value}</Text> : null}
    </Pressable>
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
  xBar: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  dateLine: { color: Colors.textSecondary, fontSize: 13, paddingHorizontal: 4 },
  liCounts: { flexDirection: "row", alignItems: "center", gap: 5, paddingHorizontal: 4 },
  liLikeDot: { width: 16, height: 16, borderRadius: 8, backgroundColor: LINKEDIN_BLUE, alignItems: "center", justifyContent: "center" },
  liBar: {
    flexDirection: "row",
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingTop: 4,
  },
  liAction: { flex: 1, alignItems: "center", justifyContent: "center", gap: 2, minHeight: 48 },
  liActionText: { color: Colors.textSecondary, fontSize: 11, fontWeight: "600" },
  dots: { flexDirection: "row", justifyContent: "center", gap: 5 },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: Colors.border },
  dotActive: { backgroundColor: Colors.accent },
  dateLineStrong: { color: Colors.textPrimary, fontWeight: "700" },
  video: { width: "100%", aspectRatio: 16 / 9, borderRadius: 12, overflow: "hidden", backgroundColor: "#000" },
  videoWeb: { flex: 1, backgroundColor: "#000" },
  quoteCard: { borderWidth: 1, borderColor: Colors.border, borderRadius: 16, padding: 12, gap: 8 },
  quoteHeader: { flexDirection: "row", alignItems: "center", gap: 6 },
  quoteAvatar: { width: 20, height: 20, borderRadius: 10 },
  quoteName: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700", flexShrink: 1 },
  quoteHandle: { color: Colors.textSecondary, fontSize: 14, flexShrink: 1 },
  quoteText: { color: Colors.textPrimary, fontSize: 14, lineHeight: 20 },
  quoteTitle: { color: Colors.textPrimary, fontSize: 15, fontWeight: "800", lineHeight: 21 },
  quoteImage: { width: "100%", aspectRatio: 16 / 9, borderRadius: 12, backgroundColor: Colors.card },
  barBtn: { flexDirection: "row", alignItems: "center", gap: 5, minHeight: 44, minWidth: 36, paddingHorizontal: 4 },
  barText: { color: Colors.textSecondary, fontSize: 13, fontVariant: ["tabular-nums"] },
  redditBar: { flexDirection: "row", alignItems: "center", flexWrap: "wrap", gap: 8 },
  votePill: { flexDirection: "row", alignItems: "center", height: 40, borderRadius: 20, backgroundColor: Colors.input },
  voteBtn: { width: 40, height: 40, alignItems: "center", justifyContent: "center" },
  voteText: { color: Colors.textPrimary, fontSize: 13, fontWeight: "700", fontVariant: ["tabular-nums"] },
  redditPill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 40,
    paddingHorizontal: 14,
    borderRadius: 20,
    backgroundColor: Colors.input,
  },
  redditPillText: { color: Colors.textPrimary, fontSize: 13, fontWeight: "700" },
  bottomRow: { flexDirection: "row", gap: 8 },
  bottomBtn: { flex: 1 },
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
