// "Also on": groups the sources a user follows into people and companies,
// and lists where else each one has an account. Data comes from the
// identity_links / identity_scans tables filled by the find-also-on edge
// function (web repo). Same rules as src/lib/alsoOn.ts on the web and
// ios/MyFeeds/Models/AlsoOn.swift.

import type { Channel } from "@/lib/database";
import { platformOf, type Platform } from "@/lib/platforms";
import i18n from "@/lib/i18n";

export type LinkStatus = "confirmed" | "possible" | "rejected";

export interface IdentityLink {
  id: string;
  user_id: string;
  channel_id: string;
  platform: Platform;
  match_key: string;
  handle: string | null;
  url: string;
  display_name: string | null;
  thumbnail: string | null;
  status: LinkStatus;
  method: string;
  evidence: string | null;
  decided_by_user: boolean;
  created_at: string;
  updated_at: string;
}

export interface IdentityScan {
  channel_id: string;
  user_id: string;
  scanned_at: string;
  aisa_calls: number;
  found_count: number;
  error: string | null;
}

export interface FollowedAccount {
  key: string;
  platform: Platform;
  label: string;
  url: string;
  channel: Channel;
}

export interface FoundAccount {
  kind: "confirmed" | "possible";
  key: string;
  platform: Platform;
  label: string;
  url: string;
  link: IdentityLink;
}

export interface Person {
  id: string;
  name: string;
  thumbnail: string | null;
  sources: Channel[];
  agentIds: string[];
  following: FollowedAccount[];
  also: FoundAccount[];
  possible: FoundAccount[];
  lastScannedAt: string | null;
  scanErrors: string[];
  // Cards the user combined by hand ("Combine"), kept so they can be
  // separated again.
  merges: IdentityLink[];
}

// A card combined by hand is saved as a confirmed match from one card's source
// to another followed source, keyed by that source's id: source:<channel id>.
// It only ties the two together; it's never shown as an account of its own.
// Same as the web app.
export const MERGE_KEY_PREFIX = "source:";
export const isMergeLink = (link: Pick<IdentityLink, "match_key">) => link.match_key.startsWith(MERGE_KEY_PREFIX);

// Platforms a match can be saved under (identity_links.platform). A TikTok
// source can't be the target, so the link goes the other way round.
const LINKABLE: Platform[] = [
  "youtube", "x", "instagram", "facebook", "linkedin", "reddit", "github",
  "apple_music", "apple_podcasts", "apple_books", "youtube_music", "spotify",
];

// The row that combines two cards: saved on one of `a`'s sources, pointing at
// one of `b`'s (or the other way round when only that works). Null when
// neither card has a source that can be linked to.
export function mergeLinkRow(a: Person, b: Person, userId: string) {
  const pick = (from: Person, to: Person) => {
    const target = to.sources.find((c) => LINKABLE.includes(platformOf(c.platform)));
    return target ? { owner: from.sources[0], target } : null;
  };
  const pair = pick(a, b) ?? pick(b, a);
  if (!pair) return null;
  const { owner, target } = pair;
  return {
    user_id: userId,
    channel_id: owner.id,
    platform: platformOf(target.platform),
    match_key: MERGE_KEY_PREFIX + target.id,
    handle: target.handle ?? null,
    url: target.channel_url ?? "",
    display_name: target.channel_name ?? null,
    thumbnail: target.channel_thumbnail ?? null,
    status: "confirmed" as const,
    method: "user",
    evidence: "You combined these cards.",
    decided_by_user: true,
  };
}

// Other cards with the same name, most likely the same person added twice.
export function sameNameAs(person: Person, people: Person[]): Person[] {
  const n = person.name.trim().toLowerCase();
  return people.filter((p) => p.id !== person.id && p.name.trim().toLowerCase() === n);
}

// Subreddits and keyword searches aren't people or companies. Reddit users
// are, and are saved as "account" sources.
export function isPersonSource(ch: Channel): boolean {
  if (platformOf(ch.platform) === "reddit") return ch.source_type === "account";
  return ch.source_type !== "subreddit" && ch.source_type !== "keyword";
}

function accountKeyFromUrl(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    return null;
  }
  const host = u.hostname.replace(/^(www\.|m\.|mobile\.|old\.|new\.)/, "").toLowerCase();
  const parts = u.pathname.split("/").filter(Boolean);
  const first = parts[0] ?? "";
  if (host === "reddit.com") {
    const kind = first.toLowerCase();
    return (kind === "user" || kind === "u") && parts[1] ? "reddit:u:" + parts[1].toLowerCase() : null;
  }
  if (host === "x.com" || host === "twitter.com") {
    return first ? "x:" + first.replace(/^@/, "").toLowerCase() : null;
  }
  if (host === "instagram.com") return first ? "instagram:" + first.toLowerCase() : null;
  if (host === "facebook.com" || host === "fb.com") {
    // Same key as find-also-on: facebook:<page name>.
    return /^[A-Za-z0-9.\-]{2,80}$/.test(first) && !/\.php$/i.test(first) ? "facebook:" + first.toLowerCase() : null;
  }
  if (host === "open.spotify.com") {
    // Same key as find-also-on: spotify:artist:<id> / spotify:show:<id> (ids are case-sensitive).
    const rest = first.startsWith("intl-") ? parts.slice(1) : parts;
    return (rest[0] === "artist" || rest[0] === "show") && rest[1] ? "spotify:" + rest[0] + ":" + rest[1] : null;
  }
  if (host === "music.youtube.com") {
    const channel = u.pathname.match(/\/channel\/(UC[\w-]{20,})/);
    return channel ? "youtube_music:" + channel[1] : null;
  }
  if (host === "books.apple.com" || (host === "itunes.apple.com" && /\/author\//i.test(u.pathname))) {
    const author = u.pathname.match(/\/author\/(?:[^/]+\/)?(?:id)?(\d+)/i);
    return author ? "apple_books:" + author[1] : null;
  }
  if (host === "music.apple.com" || host === "itunes.apple.com" || host === "podcasts.apple.com") {
    const artist = u.pathname.match(/\/artist\/(?:[^/]+\/)?(?:id)?(\d+)/i);
    if (artist && host !== "podcasts.apple.com") return "apple_music:" + artist[1];
    const show = u.pathname.match(/\/podcast\/(?:[^/]+\/)?id(\d+)/i);
    return show ? "apple_podcasts:" + show[1] : null;
  }
  if (host === "youtube.com") {
    if (first.startsWith("@")) return "youtube:@" + first.slice(1).toLowerCase();
    if (first === "channel" && parts[1]) return "youtube:" + parts[1];
    if ((first === "c" || first === "user") && parts[1]) return "youtube:c:" + parts[1].toLowerCase();
    return null;
  }
  if (host === "github.com") {
    // A repo link (github.com/owner/repo) belongs to its owner.
    return /^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(first) ? "github:" + first.toLowerCase() : null;
  }
  if (host === "linkedin.com" || host.endsWith(".linkedin.com")) {
    const kind = first.toLowerCase();
    if (!parts[1]) return null;
    if (kind === "in") return "linkedin:in:" + parts[1].toLowerCase();
    if (kind === "company" || kind === "school" || kind === "showcase") return "linkedin:company:" + parts[1].toLowerCase();
  }
  return null;
}

// Every key a followed source is known by (same format as match_key).
export function channelKeys(ch: Channel): string[] {
  const platform = platformOf(ch.platform);
  const keys = new Set<string>();
  const fromUrl = accountKeyFromUrl(ch.channel_url);
  if (fromUrl) keys.add(fromUrl);
  if (ch.channel_id) {
    if (platform === "youtube" && /^UC[A-Za-z0-9_-]{10,}$/.test(ch.channel_id)) keys.add("youtube:" + ch.channel_id);
    if (platform !== "youtube") keys.add(ch.channel_id.toLowerCase());
  }
  if (ch.handle && (platform === "x" || platform === "instagram")) {
    keys.add(platform + ":" + ch.handle.replace(/^@/, "").toLowerCase());
  }
  return [...keys];
}

// A found account's keys: its match_key plus the key its URL gives (a YouTube
// channel found as youtube:UC... is followed by its @handle URL).
function linkKeys(link: IdentityLink): string[] {
  const fromUrl = accountKeyFromUrl(link.url);
  return fromUrl && fromUrl !== link.match_key ? [link.match_key, fromUrl] : [link.match_key];
}

// Match notes the app itself saves (in English, in the database) shown in the
// active language. Notes written by the server pass through as they are.
const OWN_EVIDENCE = {
  "You confirmed this match.": "people.evidence.confirmed",
  "You combined these cards.": "people.evidence.combined",
} as const;
export function evidenceText(evidence: string | null | undefined): string {
  if (!evidence) return "";
  const key = OWN_EVIDENCE[evidence as keyof typeof OWN_EVIDENCE];
  return key ? i18n.t(key) : evidence;
}

// "Lena Ortiz (@lenabuilds)" -> "Lena Ortiz"
export function cleanName(name: string | null | undefined, fallback: string): string {
  const n = (name ?? "").replace(/\s*\(@[^)]*\)\s*$/, "").trim();
  return n || fallback;
}

export function accountLabel(platform: Platform, handle: string | null, url: string): string {
  if (platform === "apple_music") return i18n.t("people.labels.artistPage");
  if (platform === "apple_podcasts") return i18n.t("people.labels.show");
  if (platform === "apple_books") return i18n.t("people.labels.author");
  if (platform === "youtube_music") return i18n.t("people.labels.artist");
  if (platform === "spotify") return /\/show\//.test(url) ? i18n.t("people.labels.show") : i18n.t("people.labels.artist");
  if (!handle || platform === "facebook") return url.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "");
  if (platform === "x" || platform === "instagram" || platform === "tiktok") return "@" + handle;
  if (platform === "reddit") return "u/" + handle.replace(/^\/?u(ser)?\//i, "");
  if (platform === "youtube") return /^UC[A-Za-z0-9_-]{10,}$/.test(handle) ? i18n.t("people.labels.channel") : "@" + handle;
  return handle;
}

function sourceLabel(ch: Channel): string {
  const platform = platformOf(ch.platform);
  if (ch.handle && (platform === "x" || platform === "instagram" || platform === "tiktok")) return "@" + ch.handle.replace(/^@/, "");
  const m = (ch.channel_url ?? "").match(/youtube\.com\/@([^/?#]+)/);
  if (m) return "@" + m[1];
  if ((platform === "linkedin" || platform === "github") && ch.handle) return ch.handle;
  if (platform === "reddit" && ch.handle) return "u/" + ch.handle.replace(/^\/?u(ser)?\//i, "");
  return cleanName(ch.channel_name, ch.channel_url ?? i18n.t("agentDetail.source"));
}

export function buildPeople(channels: Channel[], links: IdentityLink[], scans: IdentityScan[]): Person[] {
  const sources = channels.filter(isPersonSource);
  const byId = new Map(sources.map((c) => [c.id, c]));
  const keyToSource = new Map<string, string>();
  for (const ch of sources) for (const k of channelKeys(ch)) if (!keyToSource.has(k)) keyToSource.set(k, ch.id);
  for (const ch of sources) keyToSource.set(MERGE_KEY_PREFIX + ch.id, ch.id);

  // The same account followed in two agents is one person.
  const parent = new Map<string, string>();
  const find = (id: string): string => {
    let root = id;
    while (parent.get(root) && parent.get(root) !== root) root = parent.get(root)!;
    parent.set(id, root);
    return root;
  };
  const union = (a: string, b: string) => {
    const ra = find(a);
    const rb = find(b);
    if (ra !== rb) parent.set(rb, ra);
  };
  for (const ch of sources) parent.set(ch.id, ch.id);
  for (const ch of sources) {
    for (const k of channelKeys(ch)) {
      const other = keyToSource.get(k);
      if (other && other !== ch.id) union(ch.id, other);
    }
  }
  // Confirmed links that point at another followed source join the two.
  for (const link of links) {
    if (link.status !== "confirmed" || !byId.has(link.channel_id)) continue;
    for (const k of linkKeys(link)) {
      const other = keyToSource.get(k);
      if (other && other !== link.channel_id) union(link.channel_id, other);
    }
  }

  const groups = new Map<string, Channel[]>();
  for (const ch of sources) {
    const root = find(ch.id);
    groups.set(root, [...(groups.get(root) ?? []), ch]);
  }

  const scanById = new Map(scans.map((s) => [s.channel_id, s]));
  const people: Person[] = [];

  for (const [root, group] of groups) {
    const sorted = [...group].sort((a, b) => (b.priority ?? 3) - (a.priority ?? 3));
    const lead = sorted[0];
    const groupKeys = new Set(group.flatMap(channelKeys));
    for (const c of group) groupKeys.add(MERGE_KEY_PREFIX + c.id);
    const groupIds = new Set(group.map((c) => c.id));

    const following: FollowedAccount[] = [];
    const seenFollow = new Set<string>();
    for (const ch of sorted) {
      const platform = platformOf(ch.platform);
      const key = channelKeys(ch)[0] ?? ch.id;
      if (seenFollow.has(platform + ":" + key)) continue;
      seenFollow.add(platform + ":" + key);
      following.push({ key, platform, label: sourceLabel(ch), url: ch.channel_url ?? "", channel: ch });
    }

    const groupLinks = links.filter((l) => groupIds.has(l.channel_id));
    const rejected = new Set(groupLinks.filter((l) => l.status === "rejected").map((l) => l.match_key));
    const confirmedKeys = new Set(groupLinks.filter((l) => l.status === "confirmed").map((l) => l.match_key));
    const also: FoundAccount[] = [];
    const possible: FoundAccount[] = [];
    const seen = new Set<string>();
    // Confirmed first so a key confirmed by one source isn't also shown as possible.
    const ordered = [...groupLinks].sort((a, b) => (a.status === "confirmed" ? 0 : 1) - (b.status === "confirmed" ? 0 : 1));
    for (const link of ordered) {
      // Cards combined by hand: the link only joins them, it's not an account.
      if (isMergeLink(link)) continue;
      if (link.status === "rejected" || rejected.has(link.match_key)) continue;
      if (linkKeys(link).some((k) => groupKeys.has(k)) || seen.has(link.match_key)) continue;
      if (link.status === "possible" && confirmedKeys.has(link.match_key)) continue;
      seen.add(link.match_key);
      const platform = platformOf(link.platform);
      const item: FoundAccount = {
        kind: link.status === "confirmed" ? "confirmed" : "possible",
        key: link.match_key,
        platform,
        label: accountLabel(platform, link.handle, link.url),
        url: link.url,
        link,
      };
      if (item.kind === "confirmed") also.push(item);
      else possible.push(item);
    }

    const groupScans = group.map((c) => scanById.get(c.id)).filter(Boolean) as IdentityScan[];
    const lastScannedAt = groupScans.length ? groupScans.map((s) => s.scanned_at).sort().slice(-1)[0] : null;

    // A source added moments ago (a YouTube link before its first run) has no
    // name or picture yet; a confirmed match on another platform stands in.
    const named = sorted.find((c) => c.channel_name);
    const matchName = also.find((a) => a.link.display_name)?.link.display_name ?? null;
    const matchPicture = also.find((a) => a.link.thumbnail)?.link.thumbnail ?? null;

    people.push({
      id: root,
      name: named ? cleanName(named.channel_name, sourceLabel(named)) : matchName ?? cleanName(lead.channel_name, sourceLabel(lead)),
      thumbnail: sorted.find((c) => c.channel_thumbnail)?.channel_thumbnail ?? matchPicture,
      sources: sorted,
      agentIds: [...new Set(sorted.map((c) => c.agent_id))],
      following,
      also,
      possible,
      lastScannedAt,
      scanErrors: groupScans.map((s) => s.error).filter(Boolean) as string[],
      merges: groupLinks.filter((l) => isMergeLink(l) && l.status === "confirmed"),
    });
  }

  return people.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
}

// Where to follow this account on the platform itself. X and YouTube open their
// own follow / subscribe prompt; LinkedIn and Instagram open the profile, since
// neither lets other apps follow accounts for the user.
export function platformFollowUrl(platform: Platform, url: string): string {
  const key = accountKeyFromUrl(url);
  if (platform === "x" && key?.startsWith("x:")) {
    return "https://x.com/intent/follow?screen_name=" + encodeURIComponent(key.slice(2));
  }
  if (platform === "youtube") {
    try {
      const u = new URL(url);
      u.searchParams.set("sub_confirmation", "1");
      return u.toString();
    } catch {
      return url;
    }
  }
  return url;
}

export function initials(name: string): string {
  const parts = name.replace(/^r\//, "").split(/\s+/).filter(Boolean);
  const letters = parts.length > 1 ? parts[0][0] + parts[1][0] : (parts[0] ?? "?").slice(0, 2);
  return letters.toUpperCase();
}

// "Not searched yet" / "Only on X" / "On 3 platforms · 1 you don't follow · 1 to check"
export function personSummary(p: Person, platformLabel: (p: Platform) => string): string {
  const total = p.following.length + p.also.length;
  const parts: string[] = [];
  if (!p.lastScannedAt) parts.push(i18n.t("people.notSearched"));
  else if (total === 1) parts.push(i18n.t("people.onlyOn", { platform: platformLabel(p.following[0].platform) }));
  else parts.push(i18n.t("people.onPlatforms", { count: total }));
  if (p.also.length) parts.push(i18n.t("people.notFollowed", { count: p.also.length }));
  if (p.possible.length) parts.push(i18n.t("people.toCheck", { count: p.possible.length }));
  return parts.join(" · ");
}
