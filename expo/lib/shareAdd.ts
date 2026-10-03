// Share to My Feeds: turns whatever another app shared (a profile link, a
// post link, or text with a link in it) into an account the user can add to
// one or more collections in one step. The add-source edge function does the
// work (preview: true). Same calls as src/lib/shareAdd.ts in the web repo and
// ios/MyFeedsShare/ShareAPI.swift.
import { supabase } from "@/lib/supabase";
import { extractEdgeFunctionErrorMessage } from "@/lib/hooks";
import type { Platform } from "@/lib/platforms";

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
  throw new Error(data?.error ?? "Couldn't read that link.");
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
        body: { agentIds: args.agentIds, platform: t.platform, value: t.value, priority: args.priority },
      });
      const added: AddedChannel[] = data?.channels ?? (data?.channel ? [data.channel] : []);
      // The main account has to go in; their other accounts are best effort.
      if (i === 0 && added.length === 0) {
        if (data?.error) throw new Error(data.error);
        throw new Error(error ? await extractEdgeFunctionErrorMessage(error) : "Couldn't add that account.");
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

export function joinNames(names: string[]): string {
  if (names.length <= 1) return names.join("");
  if (names.length === 2) return `${names[0]} and ${names[1]}`;
  return `${names.slice(0, -1).join(", ")} and ${names[names.length - 1]}`;
}

export const PRIORITY_NAMES: Record<number, string> = { 1: "Lowest", 2: "Low", 3: "Normal", 4: "High", 5: "Highest" };
