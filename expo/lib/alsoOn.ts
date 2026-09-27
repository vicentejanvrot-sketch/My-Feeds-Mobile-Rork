// "Also on": groups the sources a user follows into people and companies,
// and lists where else each one has an account. Data comes from the
// identity_links / identity_scans tables filled by the find-also-on edge
// function (web repo). Same rules as src/lib/alsoOn.ts on the web and
// ios/MyFeeds/Models/AlsoOn.swift.

import type { Channel } from "@/lib/database";
import { platformOf, type Platform } from "@/lib/platforms";

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
}

// Subreddits and keyword searches aren't people or companies.
export function isPersonSource(ch: Channel): boolean {
  return platformOf(ch.platform) !== "reddit" && ch.source_type !== "subreddit" && ch.source_type !== "keyword";
}

function accountKeyFromUrl(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    return null;
  }
  const host = u.hostname.replace(/^(www\.|m\.|mobile\.)/, "").toLowerCase();
  const parts = u.pathname.split("/").filter(Boolean);
  const first = parts[0] ?? "";
  if (host === "x.com" || host === "twitter.com") {
    return first ? "x:" + first.replace(/^@/, "").toLowerCase() : null;
  }
  if (host === "instagram.com") return first ? "instagram:" + first.toLowerCase() : null;
  if (host === "youtube.com") {
    if (first.startsWith("@")) return "youtube:@" + first.slice(1).toLowerCase();
    if (first === "channel" && parts[1]) return "youtube:" + parts[1];
    if ((first === "c" || first === "user") && parts[1]) return "youtube:c:" + parts[1].toLowerCase();
    return null;
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

// "Lena Ortiz (@lenabuilds)" -> "Lena Ortiz"
export function cleanName(name: string | null | undefined, fallback: string): string {
  const n = (name ?? "").replace(/\s*\(@[^)]*\)\s*$/, "").trim();
  return n || fallback;
}

export function accountLabel(platform: Platform, handle: string | null, url: string): string {
  if (!handle) return url.replace(/^https?:\/\/(www\.)?/, "").replace(/\/$/, "");
  if (platform === "x" || platform === "instagram") return "@" + handle;
  if (platform === "youtube") return /^UC[A-Za-z0-9_-]{10,}$/.test(handle) ? "Channel" : "@" + handle;
  return handle;
}

function sourceLabel(ch: Channel): string {
  const platform = platformOf(ch.platform);
  if (ch.handle && (platform === "x" || platform === "instagram")) return "@" + ch.handle.replace(/^@/, "");
  const m = (ch.channel_url ?? "").match(/youtube\.com\/@([^/?#]+)/);
  if (m) return "@" + m[1];
  if (platform === "linkedin" && ch.handle) return ch.handle;
  return cleanName(ch.channel_name, ch.channel_url ?? "Source");
}

export function buildPeople(channels: Channel[], links: IdentityLink[], scans: IdentityScan[]): Person[] {
  const sources = channels.filter(isPersonSource);
  const byId = new Map(sources.map((c) => [c.id, c]));
  const keyToSource = new Map<string, string>();
  for (const ch of sources) for (const k of channelKeys(ch)) if (!keyToSource.has(k)) keyToSource.set(k, ch.id);

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

    people.push({
      id: root,
      name: cleanName(lead.channel_name, sourceLabel(lead)),
      thumbnail: sorted.find((c) => c.channel_thumbnail)?.channel_thumbnail ?? null,
      sources: sorted,
      agentIds: [...new Set(sorted.map((c) => c.agent_id))],
      following,
      also,
      possible,
      lastScannedAt,
      scanErrors: groupScans.map((s) => s.error).filter(Boolean) as string[],
    });
  }

  return people.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }));
}

export function initials(name: string): string {
  const parts = name.replace(/^r\//, "").split(/\s+/).filter(Boolean);
  const letters = parts.length > 1 ? parts[0][0] + parts[1][0] : (parts[0] ?? "?").slice(0, 2);
  return letters.toUpperCase();
}

// "Not checked yet" / "Only on X" / "On 3 platforms · 1 you don't follow · 1 to check"
export function personSummary(p: Person, platformLabel: (p: Platform) => string): string {
  const total = p.following.length + p.also.length;
  const parts: string[] = [];
  if (!p.lastScannedAt) parts.push("Not checked yet");
  else if (total === 1) parts.push("Only on " + platformLabel(p.following[0].platform));
  else parts.push("On " + total + " platforms");
  if (p.also.length) parts.push(p.also.length + " you don't follow");
  if (p.possible.length) parts.push(p.possible.length + " to check");
  return parts.join(" · ");
}
