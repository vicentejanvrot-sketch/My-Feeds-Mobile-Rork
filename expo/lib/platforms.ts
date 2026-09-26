// One place for platform names, colours and helpers, so every screen labels
// sources the same way. Keep in sync with src/lib/platforms.ts (web) and
// ios/MyFeeds/Models/Platform.swift in the mobile repo.

export type Platform = "youtube" | "x" | "reddit";

export const PLATFORMS: Platform[] = ["youtube", "x", "reddit"];

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
    sourceNoun: "Subreddit",
    addPlaceholder: "r/subreddit or a reddit.com link",
    addHelp: "Top posts from the lookback window.",
    openLabel: "Open on Reddit",
  },
};

export function platformOf(value: string | null | undefined): Platform {
  return value === "x" || value === "reddit" ? value : "youtube";
}

// Non-YouTube items store "x:<id>" / "reddit:<id>" in items.video_id.
export function isPostVideoId(videoId: string | null | undefined): boolean {
  return !!videoId && /^(x|reddit):/.test(videoId);
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
