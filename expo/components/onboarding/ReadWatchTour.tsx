import { useState } from "react";
import { Pressable, ScrollView, StyleSheet, Text, View } from "react-native";
import type { LucideIcon } from "lucide-react-native";
import {
  ArrowBigDown,
  ArrowBigUp,
  Bookmark,
  CheckCircle2,
  Clock,
  ExternalLink,
  GitFork,
  Heart,
  MessageCircle,
  MessageSquare,
  Play,
  Repeat2,
  Star,
  ThumbsUp,
} from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { PlatformBadge } from "@/components/PlatformBadge";
import { Platform, PLATFORMS, PLATFORM_META } from "@/lib/platforms";

// Onboarding walkthrough of how to read, watch and act on content, one platform
// at a time. Same content as the web ReadWatchTour and the iOS ReadWatchTourView:
// a sample post with three numbered spots that match what the feed, the video
// player and the post reader actually do.

interface TourAction {
  icon: LucideIcon;
  label: string;
}

interface Tour {
  author: string;
  handle: string;
  when: string;
  media: "video" | "photo" | "text";
  title?: string;
  body?: string;
  quote?: { author: string; handle: string; text: string };
  steps: { title: string; body: string }[];
  // Spot 2 and spot 3 are rows of actions (YouTube uses its own summary and status rows).
  saveActions: TourAction[];
  outActions: TourAction[];
  outNote?: string;
}

// One tour per platform.
const TOURS: Record<Platform, Tour> = {
  youtube: {
    author: "Two Minute Markets",
    handle: "YouTube",
    when: "2h",
    media: "video",
    title: "Why small caps lag when rates rise",
    steps: [
      { title: "Play it here", body: "Tap the video to watch it inside My Feeds. It remembers where you stopped." },
      { title: "Jump to the good parts", body: "Under the player, the summary lists the key moments. Tap a time to jump straight there." },
      { title: "Keep track", body: "Mark it Watched, Watch later or Liked from the card so your feed stays tidy." },
    ],
    saveActions: [],
    outActions: [],
  },
  x: {
    author: "Lena Ortiz",
    handle: "@lena_builds",
    when: "5h",
    media: "text",
    body: "Onboarding rewrite is live. A thread on what we cut and why.",
    quote: { author: "Design Notes Daily", handle: "@designnotes", text: "The best onboarding asks for one decision per screen." },
    steps: [
      { title: "Read the whole post", body: "Tap the post to open it. Photos, videos and quoted posts show in full inside My Feeds." },
      { title: "Like or bookmark", body: "Like saves it in My Feeds. Bookmark adds it to Read later." },
      { title: "Reply or repost on X", body: "Replying and reposting open X, because they post from your X account." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Bookmark" }],
    outActions: [{ icon: MessageCircle, label: "Reply" }, { icon: Repeat2, label: "Repost" }],
    outNote: "Opens X",
  },
  reddit: {
    author: "r/PowerApps",
    handle: "u/canvas_dev",
    when: "8h",
    media: "text",
    title: "Patching a collection without the delegation warning?",
    body: "I've got a gallery over 2,000 rows and Patch keeps complaining. What's the cleanest way around it?",
    steps: [
      { title: "Open the post", body: "Tap it to read the full post with its photos or video, plus a summary of the thread." },
      { title: "Upvote to save", body: "Upvote saves it in My Feeds, downvote marks it as read, and Save adds it to Read later." },
      { title: "Comments open on Reddit", body: "Tap the comment count to join the conversation on Reddit." },
    ],
    saveActions: [{ icon: ArrowBigUp, label: "Upvote" }, { icon: ArrowBigDown, label: "Downvote" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: MessageSquare, label: "Comments" }],
    outNote: "Opens Reddit",
  },
  github: {
    author: "openfeeds",
    handle: "New release",
    when: "1d",
    media: "text",
    title: "openfeeds/parser v1.4.0",
    body: "Release notes for the parser, with a short summary of what changed.",
    steps: [
      { title: "See what's new", body: "Tap a new repository or release to read what it is, with a short summary." },
      { title: "Star to save", body: "Star saves it in My Feeds. Save adds it to Read later." },
      { title: "Fork on GitHub", body: "Forking opens GitHub, since it happens in your GitHub account." },
    ],
    saveActions: [{ icon: Star, label: "Star" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: GitFork, label: "Fork" }],
    outNote: "Opens GitHub",
  },
  instagram: {
    author: "Ember Kitchen",
    handle: "@emberkitchen",
    when: "3h",
    media: "photo",
    body: "Three ways to use up leftover rice this week.",
    steps: [
      { title: "Photos and reels play here", body: "Tap the post to open it. Swipe through carousels and play reels without leaving." },
      { title: "Heart to save", body: "The heart saves it in My Feeds, and the bookmark adds it to Read later." },
      { title: "Comments open on Instagram", body: "Commenting opens Instagram, because it posts from your account." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: MessageCircle, label: "Comment" }],
    outNote: "Opens Instagram",
  },
  linkedin: {
    author: "Maya Chen",
    handle: "Product lead",
    when: "1d",
    media: "text",
    body: "We cut our onboarding from nine screens to three. Here's what we learned about asking for less up front.",
    steps: [
      { title: "Read the full post", body: "Tap it to read the whole post and see its images inside My Feeds." },
      { title: "Like to save", body: "Like saves it in My Feeds. Save adds it to Read later." },
      { title: "Comment and repost on LinkedIn", body: "Those open LinkedIn, since they post from your account." },
    ],
    saveActions: [{ icon: ThumbsUp, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: MessageCircle, label: "Comment" }, { icon: Repeat2, label: "Repost" }],
    outNote: "Opens LinkedIn",
  },
  tiktok: {
    author: "Ember Kitchen",
    handle: "@emberkitchen",
    when: "4h",
    media: "video",
    body: "Crispy rice in 60 seconds.",
    steps: [
      { title: "Watch it here", body: "Tap the video to play it inside My Feeds with TikTok's own player." },
      { title: "Like to save", body: "Like saves it in My Feeds. Save adds it to Read later." },
      { title: "Comments open on TikTok", body: "Commenting opens TikTok, because it posts from your account." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: MessageCircle, label: "Comment" }],
    outNote: "Opens TikTok",
  },
  facebook: {
    author: "City Parks & Rec",
    handle: "Page",
    when: "6h",
    media: "photo",
    body: "The riverside trail reopens Saturday. Here's what changed.",
    steps: [
      { title: "Read and watch here", body: "Tap the post to read it in full. Photos open large and videos play inside My Feeds." },
      { title: "Like to save", body: "Like saves it in My Feeds. Save adds it to Read later." },
      { title: "Comments open on Facebook", body: "Commenting opens Facebook, because it posts from your account." },
    ],
    saveActions: [{ icon: ThumbsUp, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: MessageCircle, label: "Comment" }],
    outNote: "Opens Facebook",
  },
  apple_music: {
    author: "Nova Lane",
    handle: "New single",
    when: "1d",
    media: "video",
    title: "Paper Lanterns",
    body: "New single by Nova Lane · 1 track · Pop",
    steps: [
      { title: "Listen here", body: "Tap it to open Apple Music's player. You hear a preview, or the full songs if you're signed in to Apple Music." },
      { title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later." },
      { title: "Add it to Apple Music", body: "\"Add album to Apple Music\" puts the songs in your My Feeds playlist there, ready to download for offline." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: ExternalLink, label: "Apple Music" }],
    outNote: "Opens Apple Music",
  },
  apple_podcasts: {
    author: "The Long Run",
    handle: "Podcast",
    when: "5h",
    media: "video",
    title: "Episode 212: Training through the winter",
    body: "Full episode, played inside My Feeds.",
    steps: [
      { title: "Listen to the whole episode", body: "Tap it to play the full episode here. It remembers where you stopped, on every device." },
      { title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later." },
      { title: "Follow the show on Apple Podcasts", body: "Following or rating the show opens Apple Podcasts." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: ExternalLink, label: "Apple Podcasts" }],
    outNote: "Opens Apple Podcasts",
  },
  apple_books: {
    author: "Maya Ortiz",
    handle: "Audiobook",
    when: "2d",
    media: "photo",
    title: "The Quiet Harbor",
    body: "New audiobook by Maya Ortiz · Fiction",
    steps: [
      { title: "Hear a sample", body: "Tap it to see the cover and description, and play Apple's sample right here." },
      { title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later." },
      { title: "Listen in Apple Books", body: "Buying and listening to the whole book opens Apple Books." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: ExternalLink, label: "Apple Books" }],
    outNote: "Opens Apple Books",
  },
  youtube_music: {
    author: "Nova Lane",
    handle: "New album",
    when: "1d",
    media: "video",
    title: "Night Garden",
    body: "New album by Nova Lane · 10 tracks",
    steps: [
      { title: "Listen here", body: "Tap it to play the songs, or the music video, right inside My Feeds." },
      { title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later." },
      { title: "Add it to YouTube Music", body: "\"Add to YouTube Music\" puts the songs in your My Feeds playlist there, using your connected YouTube account." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: ExternalLink, label: "YouTube Music" }],
    outNote: "Opens YouTube Music",
  },
  spotify: {
    author: "Nova Lane",
    handle: "New single",
    when: "1d",
    media: "video",
    title: "Paper Lanterns",
    body: "New single by Nova Lane · 1 track · Pop",
    steps: [
      { title: "Listen here", body: "Tap it to open Spotify's player and hear a preview right inside My Feeds." },
      { title: "Heart to save", body: "The heart saves it in My Feeds. Save adds it to Watch later." },
      { title: "Play it in Spotify", body: "\"Open in Spotify\" plays the full release in the Spotify app, where you can like it or add it to a playlist." },
    ],
    saveActions: [{ icon: Heart, label: "Like" }, { icon: Bookmark, label: "Save" }],
    outActions: [{ icon: ExternalLink, label: "Spotify" }],
    outNote: "Opens Spotify",
  },
};

function Marker({ n, label, active, onPick }: { n: number; label: string; active: boolean; onPick: () => void }) {
  return (
    <Pressable
      onPress={onPick}
      hitSlop={6}
      accessibilityRole="button"
      accessibilityLabel={`${n}, ${label}`}
      accessibilityState={{ selected: active }}
      style={[styles.marker, active ? styles.markerActive : styles.markerIdle]}
    >
      <Text style={[styles.markerText, { color: active ? Colors.white : Colors.accent }]}>{n}</Text>
    </Pressable>
  );
}

function ActionPill({ action }: { action: TourAction }) {
  const Icon = action.icon;
  return (
    <View style={styles.pill}>
      <Icon size={15} color={Colors.textPrimary} />
      <Text style={styles.pillText}>{action.label}</Text>
    </View>
  );
}

export function ReadWatchTour({ defaultPlatform = "youtube" }: { defaultPlatform?: Platform }) {
  const [platform, setPlatform] = useState<Platform>(defaultPlatform);
  const [spot, setSpot] = useState(0);
  const tour = TOURS[platform];

  const pickPlatform = (p: Platform) => {
    setPlatform(p);
    setSpot(0);
  };

  const zoneStyle = (index: number) => [styles.zone, spot === index && styles.zoneActive];

  return (
    <View style={styles.root}>
      {/* Platform picker */}
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.chips}>
        {PLATFORMS.map((p) => {
          const selected = platform === p;
          return (
            <Pressable
              key={p}
              onPress={() => pickPlatform(p)}
              accessibilityRole="tab"
              accessibilityState={{ selected }}
              style={[styles.chip, selected && styles.chipSelected]}
            >
              <PlatformBadge platform={p} />
              <Text style={styles.chipText}>{PLATFORM_META[p].label}</Text>
            </Pressable>
          );
        })}
      </ScrollView>

      {/* Sample card */}
      <View style={styles.card}>
        <View style={styles.cardHeader}>
          <PlatformBadge platform={platform} size="md" />
          <View style={{ flex: 1 }}>
            <Text style={styles.author} numberOfLines={1}>{tour.author}</Text>
            <Text style={styles.handle} numberOfLines={1}>{tour.handle} · {tour.when}</Text>
          </View>
        </View>

        {/* Spot 1: the content itself */}
        <View style={[zoneStyle(0), { paddingTop: 10 }]}>
          {tour.media !== "text" ? (
            <View style={styles.mediaBox}>
              {tour.media === "video" ? (
                <View style={styles.playCircle}>
                  <Play size={20} color={Colors.background} fill={Colors.background} />
                </View>
              ) : (
                <View style={styles.carouselCount}>
                  <Text style={styles.carouselText}>1 / 3</Text>
                </View>
              )}
            </View>
          ) : null}
          {tour.title ? <Text style={styles.postTitle}>{tour.title}</Text> : null}
          {tour.body ? <Text style={styles.postBody}>{tour.body}</Text> : null}
          {tour.quote ? (
            <View style={styles.quote}>
              <Text style={styles.quoteAuthor}>
                {tour.quote.author} <Text style={styles.handle}>{tour.quote.handle}</Text>
              </Text>
              <Text style={styles.postBody}>{tour.quote.text}</Text>
            </View>
          ) : null}
          <View style={styles.markerTopLeft}>
            <Marker n={1} label={tour.steps[0].title} active={spot === 0} onPick={() => setSpot(0)} />
          </View>
        </View>

        {/* Spot 2 */}
        <View style={[zoneStyle(1), styles.zoneWithMarker]}>
          {platform === "youtube" ? (
            <View style={{ gap: 6 }}>
              <Text style={styles.summaryLabel}>FROM THE TRANSCRIPT</Text>
              <View style={styles.momentRow}>
                <Text style={styles.moment}>4:10</Text>
                <Text style={styles.postBody}>When small-cap loans reset</Text>
              </View>
              <View style={styles.momentRow}>
                <Text style={styles.moment}>11:32</Text>
                <Text style={styles.postBody}>What would change his view</Text>
              </View>
            </View>
          ) : (
            <View style={styles.pillRow}>
              {tour.saveActions.map((a) => <ActionPill key={a.label} action={a} />)}
            </View>
          )}
          <View style={styles.markerTopRight}>
            <Marker n={2} label={tour.steps[1].title} active={spot === 1} onPick={() => setSpot(1)} />
          </View>
        </View>

        {/* Spot 3 */}
        <View style={[zoneStyle(2), styles.zoneWithMarker]}>
          {platform === "youtube" ? (
            <View style={styles.pillRow}>
              <ActionPill action={{ icon: CheckCircle2, label: "Watched" }} />
              <ActionPill action={{ icon: Clock, label: "Watch later" }} />
              <ActionPill action={{ icon: Heart, label: "Liked" }} />
            </View>
          ) : (
            <View style={styles.pillRow}>
              {tour.outActions.map((a) => <ActionPill key={a.label} action={a} />)}
              {tour.outNote ? (
                <View style={styles.outNote}>
                  <ExternalLink size={13} color={Colors.textSecondary} />
                  <Text style={styles.handle}>{tour.outNote}</Text>
                </View>
              ) : null}
            </View>
          )}
          <View style={styles.markerTopRight}>
            <Marker n={3} label={tour.steps[2].title} active={spot === 2} onPick={() => setSpot(2)} />
          </View>
        </View>
      </View>

      {/* Explanations for the chosen platform */}
      <View style={{ gap: 8 }}>
        {tour.steps.map((s, i) => {
          const active = spot === i;
          return (
            <Pressable
              key={s.title}
              onPress={() => setSpot(i)}
              accessibilityRole="button"
              accessibilityState={{ selected: active }}
              style={[styles.explain, active && styles.explainActive]}
            >
              <View style={styles.explainHead}>
                <View style={[styles.explainNum, active ? styles.markerActive : styles.markerIdle]}>
                  <Text style={[styles.explainNumText, { color: active ? Colors.white : Colors.accent }]}>{i + 1}</Text>
                </View>
                <Text style={styles.explainTitle}>{s.title}</Text>
              </View>
              <Text style={styles.explainBody}>{s.body}</Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: { gap: 14 },
  chips: { gap: 8, paddingVertical: 2 },
  chip: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    height: 40,
    paddingHorizontal: 12,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  chipSelected: { borderColor: Colors.accent, backgroundColor: "hsla(199, 89%, 48%, 0.12)" },
  chipText: { color: Colors.textPrimary, fontSize: 14, fontWeight: "600" as const },
  card: {
    borderRadius: 12,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    backgroundColor: Colors.card,
    padding: 12,
    gap: 10,
  },
  cardHeader: { flexDirection: "row", alignItems: "center", gap: 10 },
  author: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700" as const },
  handle: { color: Colors.textSecondary, fontSize: 12 },
  zone: { borderRadius: 10, padding: 8, gap: 8, position: "relative" },
  zoneActive: {
    borderWidth: 2,
    borderColor: "hsla(199, 89%, 48%, 0.6)",
    backgroundColor: "hsla(199, 89%, 48%, 0.06)",
    padding: 6,
  },
  zoneWithMarker: { paddingRight: 46 },
  mediaBox: {
    height: 130,
    borderRadius: 8,
    backgroundColor: Colors.input,
    alignItems: "center",
    justifyContent: "center",
  },
  playCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: "hsla(220, 20%, 92%, 0.92)",
    alignItems: "center",
    justifyContent: "center",
  },
  carouselCount: {
    position: "absolute",
    right: 8,
    bottom: 8,
    backgroundColor: "rgba(0,0,0,0.6)",
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 2,
  },
  carouselText: { color: Colors.white, fontSize: 11, fontWeight: "700" as const },
  postTitle: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700" as const },
  postBody: { color: Colors.textPrimary, fontSize: 14, lineHeight: 20, flexShrink: 1 },
  quote: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: Colors.border,
    borderRadius: 10,
    padding: 10,
    backgroundColor: Colors.input,
    gap: 2,
  },
  quoteAuthor: { color: Colors.textPrimary, fontSize: 13, fontWeight: "700" as const },
  summaryLabel: { color: Colors.accent, fontSize: 11, fontWeight: "800" as const, letterSpacing: 0.6 },
  momentRow: { flexDirection: "row", alignItems: "flex-start", gap: 8 },
  moment: {
    color: Colors.accent,
    fontSize: 12,
    fontWeight: "800" as const,
    backgroundColor: "hsla(199, 89%, 48%, 0.14)",
    borderRadius: 4,
    paddingHorizontal: 6,
    paddingVertical: 2,
    overflow: "hidden",
  },
  pillRow: { flexDirection: "row", flexWrap: "wrap", alignItems: "center", gap: 8 },
  pill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 32,
    paddingHorizontal: 12,
    borderRadius: 999,
    backgroundColor: Colors.input,
  },
  pillText: { color: Colors.textPrimary, fontSize: 12, fontWeight: "700" as const },
  outNote: { flexDirection: "row", alignItems: "center", gap: 4 },
  markerTopLeft: { position: "absolute", top: -6, left: -6 },
  markerTopRight: { position: "absolute", top: 4, right: 4 },
  marker: {
    width: 34,
    height: 34,
    borderRadius: 17,
    borderWidth: 2,
    borderColor: Colors.accent,
    alignItems: "center",
    justifyContent: "center",
  },
  markerActive: { backgroundColor: Colors.accent },
  markerIdle: { backgroundColor: Colors.background },
  markerText: { fontSize: 14, fontWeight: "800" as const },
  explain: {
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
    padding: 12,
    gap: 4,
  },
  explainActive: { borderColor: Colors.accent, backgroundColor: "hsla(199, 89%, 48%, 0.1)" },
  explainHead: { flexDirection: "row", alignItems: "center", gap: 8 },
  explainNum: {
    width: 24,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: Colors.accent,
    alignItems: "center",
    justifyContent: "center",
  },
  explainNumText: { fontSize: 12, fontWeight: "800" as const },
  explainTitle: { color: Colors.textPrimary, fontSize: 15, fontWeight: "700" as const, flexShrink: 1 },
  explainBody: { color: Colors.textSecondary, fontSize: 14, lineHeight: 20 },
});
