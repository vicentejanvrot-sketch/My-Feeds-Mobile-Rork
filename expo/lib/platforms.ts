// One place for platform names, colours and helpers, so every screen labels
// sources the same way. Keep in sync with src/lib/platforms.ts (web) and
// ios/MyFeeds/Models/Platform.swift in the mobile repo.

export type Platform =
  | "youtube" | "x" | "reddit" | "instagram" | "linkedin" | "github" | "tiktok" | "facebook"
  | "apple_music" | "apple_podcasts";

export const PLATFORMS: Platform[] = [
  "youtube", "x", "reddit", "instagram", "linkedin", "github", "tiktok", "facebook", "apple_music", "apple_podcasts",
];

export const PLATFORM_META: Record<Platform, {
  label: string;
  short: string;
  // Badge colours on the dark theme (text / background)
  fg: string;
  bg: string;
  sourceNoun: string;
  addPlaceholder: string;
  addHelp: string;
  openLabel: string;
  // Newer sources whose data provider is still settling in.
  beta?: boolean;
}> = {
  youtube: {
    label: "YouTube",
    short: "YT",
    fg: "#FF8A84",
    bg: "#3A1D24",
    sourceNoun: "Channel",
    addPlaceholder: "https://www.youtube.com/@ChannelName",
    addHelp: "Paste the channel link.",
    openLabel: "Open on YouTube",
  },
  x: {
    label: "X",
    short: "X",
    fg: "#F1F3F5",
    bg: "#262D3B",
    sourceNoun: "Account",
    addPlaceholder: "@handle or https://x.com/handle",
    addHelp: "Original posts only. Reposts and replies are skipped.",
    openLabel: "Open on X",
  },
  reddit: {
    label: "Reddit",
    short: "r/",
    fg: "#FF9A5C",
    bg: "#3A2418",
    sourceNoun: "Subreddit or user",
    addPlaceholder: "r/subreddit, u/username or a reddit.com link",
    addHelp: "Top posts from a subreddit, or a user's own posts, from the lookback window.",
    openLabel: "Open on Reddit",
  },
  instagram: {
    label: "Instagram",
    short: "IG",
    fg: "#FF7AB2",
    bg: "#3A1830",
    sourceNoun: "Account",
    addPlaceholder: "@handle or https://www.instagram.com/handle",
    addHelp: "Public accounts only. Posts and reels from the lookback window.",
    openLabel: "Open on Instagram",
    beta: true,
  },
  linkedin: {
    label: "LinkedIn",
    short: "in",
    fg: "#7FB8F0",
    bg: "#14283D",
    sourceNoun: "Profile or company",
    addPlaceholder: "https://www.linkedin.com/in/name or /company/name",
    addHelp: "Paste a person's profile link or a company page link.",
    openLabel: "Open on LinkedIn",
    beta: true,
  },
  github: {
    label: "GitHub",
    short: "GH",
    fg: "#E6EDF3",
    bg: "#21262D",
    sourceNoun: "User or organization",
    addPlaceholder: "@username or https://github.com/username",
    addHelp: "New repositories and releases from the lookback window.",
    openLabel: "Open on GitHub",
  },
  tiktok: {
    label: "TikTok",
    short: "TT",
    fg: "#F1F3F5",
    bg: "#1F1F24",
    sourceNoun: "Account",
    addPlaceholder: "@username or https://www.tiktok.com/@username",
    addHelp: "Public accounts only. Videos from the lookback window.",
    openLabel: "Open on TikTok",
    beta: true,
  },
  facebook: {
    label: "Facebook",
    short: "FB",
    fg: "#8AB4FF",
    bg: "#14264A",
    sourceNoun: "Page",
    addPlaceholder: "https://www.facebook.com/PageName",
    addHelp: "Public Pages only. Posts from the lookback window.",
    openLabel: "Open on Facebook",
    beta: true,
  },
  apple_music: {
    label: "Apple Music",
    short: "AM",
    fg: "#FF8A9A",
    bg: "#3A1620",
    sourceNoun: "Artist",
    addPlaceholder: "Artist name or https://music.apple.com/us/artist/name/123",
    addHelp: "New singles and albums. Adding an artist also brings in their latest album.",
    openLabel: "Open in Apple Music",
    beta: true,
  },
  apple_podcasts: {
    label: "Apple Podcasts",
    short: "POD",
    fg: "#D9A6FF",
    bg: "#2A1740",
    sourceNoun: "Show",
    addPlaceholder: "Show name or https://podcasts.apple.com/us/podcast/name/id123",
    addHelp: "New episodes, played right here. Adding a show also brings in its latest episode.",
    openLabel: "Open in Apple Podcasts",
    beta: true,
  },
};

export function platformOf(value: string | null | undefined): Platform {
  return value && value !== "youtube" && (PLATFORMS as string[]).includes(value) ? (value as Platform) : "youtube";
}

// Non-YouTube items store "<platform>:<id>" in items.video_id (x, reddit, instagram, linkedin, github, tiktok, facebook, apple_music, apple_podcasts).
export function isPostVideoId(videoId: string | null | undefined): boolean {
  return !!videoId && /^(x|reddit|instagram|linkedin|github|tiktok|facebook|apple_music|apple_podcasts):/.test(videoId);
}

export function formatCount(num: number | null | undefined): string {
  if (num === null || num === undefined) return "0";
  if (num >= 1000000) return `${(num / 1000000).toFixed(1)}M`;
  if (num >= 1000) return `${(num / 1000).toFixed(1)}K`;
  return String(num);
}

export function formatClock(seconds: number): string {
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
  return `${m}:${String(s).padStart(2, "0")}`;
}

export interface KeyMoment {
  seconds: number;
  text: string;
}

export function toKeyMoments(value: unknown): KeyMoment[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((m: any) => ({ seconds: Number(m?.seconds), text: String(m?.text ?? "") }))
    .filter((m) => Number.isFinite(m.seconds) && m.text.length > 0);
}
