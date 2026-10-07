// One place for platform names, colours and helpers, so every screen labels
// sources the same way. Keep in sync with src/lib/platforms.ts (web) and
// ios/MyFeeds/Models/Platform.swift in the mobile repo.

import i18n from "@/lib/i18n";

export type Platform =
  | "youtube" | "x" | "reddit" | "instagram" | "linkedin" | "github" | "tiktok" | "facebook"
  | "apple_music" | "apple_podcasts" | "apple_books" | "youtube_music" | "spotify";


/** The platform's UI texts (source noun, add hint, open label) in the active language. */
export function platformText(p: Platform): { sourceNoun: string; addPlaceholder: string; addHelp: string; openLabel: string } {
  return {
    sourceNoun: i18n.t(`platforms.${p}.sourceNoun` as const),
    addPlaceholder: i18n.t(`platforms.${p}.addPlaceholder` as const),
    addHelp: i18n.t(`platforms.${p}.addHelp` as const),
    openLabel: i18n.t(`platforms.${p}.openLabel` as const),
  };
}

export const PLATFORMS: Platform[] = [
  "youtube", "x", "reddit", "instagram", "linkedin", "github", "tiktok", "facebook", "apple_music", "apple_podcasts", "apple_books", "youtube_music", "spotify",
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
  apple_books: {
    label: "Apple Books",
    short: "BK",
    fg: "#FFB35C",
    bg: "#3A2610",
    sourceNoun: "Author",
    addPlaceholder: "Author name or https://books.apple.com/us/author/name/id123",
    addHelp: "New audiobooks, with a sample to listen to. Adding an author also brings in their latest audiobook.",
    openLabel: "Open in Apple Books",
    beta: true,
  },
  spotify: {
    label: "Spotify",
    short: "SP",
    fg: "#1ED760",
    bg: "#12301D",
    sourceNoun: "Artist",
    addPlaceholder: "https://open.spotify.com/artist/...",
    addHelp: "New singles and albums, played with Spotify's player. Paste the artist's Spotify link. Adding an artist also brings in their latest album.",
    openLabel: "Open in Spotify",
    beta: true,
  },
  youtube_music: {
    label: "YouTube Music",
    short: "YTM",
    fg: "#FF8A84",
    bg: "#3A1D24",
    sourceNoun: "Artist",
    addPlaceholder: "Artist name or https://music.youtube.com/channel/UC...",
    addHelp: "New songs, albums and music videos. Adding an artist also brings in their latest album.",
    openLabel: "Open in YouTube Music",
    beta: true,
  },
};

/**
 * True when an account found on People can be followed as a source. Spotify
 * artists can; Spotify podcast shows only open in Spotify.
 */
export function isFollowableAccount(platform: Platform, url: string): boolean {
  if (platform === "spotify") return !/open\.spotify\.com\/(?:intl-[a-z]{2}\/)?show\//i.test(url);
  return (PLATFORMS as string[]).includes(platform);
}

export function platformOf(value: string | null | undefined): Platform {
  return value && value !== "youtube" && (PLATFORMS as string[]).includes(value) ? (value as Platform) : "youtube";
}

// Web addresses that tell us which platform a pasted link belongs to.
// A subdomain counts too (m.youtube.com, old.reddit.com, vm.tiktok.com).
const PLATFORM_HOSTS: [string, Platform][] = [
  // Before youtube.com, which it would otherwise match.
  ["music.youtube.com", "youtube_music"],
  ["youtube.com", "youtube"], ["youtu.be", "youtube"],
  ["x.com", "x"], ["twitter.com", "x"],
  ["reddit.com", "reddit"], ["redd.it", "reddit"],
  ["instagram.com", "instagram"], ["instagr.am", "instagram"],
  ["linkedin.com", "linkedin"], ["lnkd.in", "linkedin"],
  ["github.com", "github"],
  ["tiktok.com", "tiktok"],
  ["facebook.com", "facebook"], ["fb.com", "facebook"], ["fb.watch", "facebook"],
  ["music.apple.com", "apple_music"],
  ["podcasts.apple.com", "apple_podcasts"],
  ["books.apple.com", "apple_books"],
  ["open.spotify.com", "spotify"],
];

/**
 * Works out the platform from what the user pasted in Add Source, so an
 * Instagram link can't be added with YouTube selected. Returns null when the
 * text doesn't say (a plain @handle or a name could be any platform).
 * Parsed by hand because URL.hostname isn't available on every RN runtime.
 */
export function detectPlatform(value: string): Platform | null {
  const text = value.trim();
  if (!text) return null;
  if (/^\/?(r|u|user)\/[A-Za-z0-9_-]+/i.test(text)) return "reddit";

  const match = /^(?:[a-z][a-z0-9+.-]*:\/\/)?([^\/?#\s:@]+)(?::\d+)?([^?#\s]*)/i.exec(text);
  if (!match) return null;
  const host = match[1].toLowerCase().replace(/^www\./, "");
  const path = match[2].toLowerCase();
  if (!host.includes(".")) return null;

  // Old iTunes links use one host for both music and podcasts.
  if (host === "itunes.apple.com") {
    if (path.includes("/podcast")) return "apple_podcasts";
    if (path.includes("/audiobook") || path.includes("/author") || path.includes("/book/")) return "apple_books";
    if (path.includes("/artist") || path.includes("/album")) return "apple_music";
    return null;
  }
  for (const [domain, platform] of PLATFORM_HOSTS) {
    if (host === domain || host.endsWith(`.${domain}`)) return platform;
  }
  return null;
}

// Non-YouTube items store "<platform>:<id>" in items.video_id (x, reddit, instagram, linkedin, github, tiktok, facebook, apple_music, apple_podcasts, apple_books, youtube_music).
export function isPostVideoId(videoId: string | null | undefined): boolean {
  return !!videoId && /^(x|reddit|instagram|linkedin|github|tiktok|facebook|apple_music|apple_podcasts|apple_books|youtube_music|spotify):/.test(videoId);
}

// A private account's "N new posts" card (run-agent saves its video_id as
// "<platform>:newposts:<source id>:<count>"). It opens the profile in the app.
export function isNewPostsCard(videoId: string | null | undefined): boolean {
  return !!videoId && /^[a-z_]+:newposts:/.test(videoId);
}

export function formatCount(num: number | null | undefined): string {
  if (num === null || num === undefined) return "0";
  const one = (n: number) => {
    try {
      return n.toLocaleString(i18n.language === "pt-BR" ? "pt-BR" : "en-US", { minimumFractionDigits: 1, maximumFractionDigits: 1 });
    } catch {
      return n.toFixed(1);
    }
  };
  if (num >= 1000000) return i18n.t("format.millions", { value: one(num / 1000000) });
  if (num >= 1000) return i18n.t("format.thousands", { value: one(num / 1000) });
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
