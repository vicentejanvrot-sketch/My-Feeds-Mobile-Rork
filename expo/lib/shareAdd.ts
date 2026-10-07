// Share to My Feeds: turns whatever another app shared (a profile link, a
// post link, or text with a link in it) into an account the user can add to
// one or more collections in one step. The add-source edge function does the
// work (preview: true). Same calls as src/lib/shareAdd.ts in the web repo and
// ios/MyFeedsShare/ShareAPI.swift.
import { supabase } from "@/lib/supabase";
import { extractEdgeFunctionErrorMessage } from "@/lib/hooks";
import type { Platform } from "@/lib/platforms";
import i18n from "@/lib/i18n";

export const UNSORTED_ID = "__unsorted__";

export interface SharePreview {
  platform: Platform;
  platformLabel: string;
  kind: "profile" | "post";
  // The account's own link: what gets added.
  value: string;
  account: {
    name: string;
    handle: string | null;
    url: string;
    thumbnail: string | null;
    channelId: string | null;
    isPrivate: boolean;
  };
  inCollections: { agentId: string; agentName: string }[];
  suggestion: { agentId: string; agentName: string; reason: string | null } | null;
  alsoOn: { platform: Platform; url: string; label: string; matchKey: string }[];
  collections: { id: string; name: string }[];
}

export async function previewShare(shared: string): Promise<SharePreview> {
  const { data, error } = await supabase.functions.invoke("add-source", { body: { preview: true, value: shared } });
  if (data?.preview) return data.preview as SharePreview;
  if (error) throw new Error(await extractEdgeFunctionErrorMessage(error));
  throw new Error(data?.error ?? i18n.t("share.readLinkFailed"));
}

export interface AddedChannel {
  id: string;
  agent_id: string;
}

// Adds the account (and, when asked, their other accounts) to every chosen
// collection. Returns the new source rows so the add can be undone.
export async function addShared(args: {
  preview: SharePreview;
  agentIds: string[];
  priority: number;
  includeAlsoOn: boolean;
}): Promise<AddedChannel[]> {
  const targets: { platform: string; value: string }[] = [{ platform: args.preview.platform, value: args.preview.value }];
  if (args.includeAlsoOn) {
    for (const a of args.preview.alsoOn) targets.push({ platform: a.platform, value: a.url });
  }
  const results = await Promise.all(
    targets.map(async (t, i) => {
      const { data, error } = await supabase.functions.invoke("add-source", {
        body: {
          agentIds: args.agentIds,
          platform: t.platform,
          value: t.value,
          priority: args.priority,
          // A private account is kept as one: it shows on People, its posts are never fetched.
          ...(i === 0 && args.preview.account.isPrivate ? { privateAccount: true } : {}),
        },
      });
      const added: AddedChannel[] = data?.channels ?? (data?.channel ? [data.channel] : []);
      // The main account has to go in; their other accounts are best effort.
      if (i === 0 && added.length === 0) {
        if (data?.error) throw new Error(data.error);
        throw new Error(error ? await extractEdgeFunctionErrorMessage(error) : i18n.t("errors.addAccountFailed"));
      }
      return added;
    }),
  );
  return results.flat();
}

export async function undoShared(channels: AddedChannel[]): Promise<void> {
  if (channels.length === 0) return;
  const { error } = await supabase.from("channels").delete().in("id", channels.map((c) => c.id));
  if (error) throw error;
}

// A new, empty collection made from the picker while adding an account.
// Reuses one with the same name instead of making a duplicate.
export async function createCollection(name: string, existing: { id: string; name: string }[]): Promise<{ id: string; name: string }> {
  const clean = name.trim();
  if (!clean) throw new Error(i18n.t("share.nameRequired"));
  const same = existing.find((c) => c.name.trim().toLowerCase() === clean.toLowerCase());
  if (same) return same;
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) throw new Error(i18n.t("errors.signInAgain"));
  const { data, error } = await supabase.from("agents").insert({ name: clean, user_id: auth.user.id }).select("id, name").single();
  if (error) throw error;
  return { id: data.id as string, name: data.name as string };
}

// Collections A to Z, with Unsorted kept at the bottom.
export function sortCollections<T extends { id: string; name: string }>(list: T[]): T[] {
  return [...list].sort((a, b) => {
    const au = a.id === UNSORTED_ID || a.name === "Unsorted";
    const bu = b.id === UNSORTED_ID || b.name === "Unsorted";
    if (au !== bu) return au ? 1 : -1;
    return a.name.localeCompare(b.name, undefined, { sensitivity: "base" });
  });
}

export function joinNames(names: string[]): string {
  if (names.length <= 1) return names.join("");
  return i18n.t("share.list", { head: names.slice(0, -1).join(", "), last: names[names.length - 1] });
}

/** "Normal" / "Alta"… for priorities 1 to 5, in the active language. */
export function priorityName(n: number): string {
  return n >= 1 && n <= 5 ? i18n.t(`share.priority.${n as 1 | 2 | 3 | 4 | 5}`) : String(n);
}

// Who a shared link points to, from the link alone (no network): shown while
// the full lookup runs. Same rules as QuickAccount in the iOS share card.
export function quickAccountFrom(text: string): { handle: string | null; platformLabel: string } | null {
  const m = text.match(/https?:\/\/[^\s]+/i);
  if (!m) return null;
  let url: URL;
  try {
    url = new URL(m[0]);
  } catch {
    return null;
  }
  const host = url.hostname.toLowerCase();
  const is = (d: string) => host === d || host.endsWith("." + d);
  const parts = url.pathname.split("/").filter(Boolean);
  const first = (skip: string[]) => (parts[0] && !skip.includes(parts[0].toLowerCase()) ? parts[0] : null);
  const at = () => parts.find((p) => p.startsWith("@"))?.slice(1) ?? null;
  if (is("instagram.com")) {
    if (parts[0]?.toLowerCase() === "stories" && parts[1]) return { handle: parts[1], platformLabel: "Instagram" };
    return { handle: first(["p", "reel", "reels", "tv", "explore", "share", "accounts"]), platformLabel: "Instagram" };
  }
  if (is("tiktok.com")) return { handle: at(), platformLabel: "TikTok" };
  if (is("x.com") || is("twitter.com")) return { handle: first(["i", "home", "search", "intent", "share", "hashtag", "explore"]), platformLabel: "X" };
  if (is("youtube.com") || host === "youtu.be") return { handle: at(), platformLabel: "YouTube" };
  if (is("facebook.com") || is("fb.com")) {
    return { handle: first(["share", "profile.php", "watch", "groups", "events", "reel", "photo", "story.php", "permalink.php"]), platformLabel: "Facebook" };
  }
  if (is("linkedin.com")) return { handle: ["in", "company"].includes(parts[0]?.toLowerCase() ?? "") ? parts[1] ?? null : null, platformLabel: "LinkedIn" };
  if (is("reddit.com")) return { handle: ["r", "u", "user"].includes(parts[0]?.toLowerCase() ?? "") ? parts[1] ?? null : null, platformLabel: "Reddit" };
  return null;
}
