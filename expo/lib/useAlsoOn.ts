// Data for the Following screen: identity links and scans, running scans,
// Same person / Not them, and following a found account. Same behaviour as
// src/hooks/useAlsoOn.ts on the web.
import { useCallback, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/lib/auth-provider";
import { extractEdgeFunctionErrorMessage } from "@/lib/hooks";
import type { Platform } from "@/lib/platforms";
import { MERGE_KEY_PREFIX, mergeLinkRow, type IdentityLink, type IdentityScan, type Person } from "@/lib/alsoOn";
import i18n from "@/lib/i18n";

export const alsoOnKeys = {
  links: ["also-on", "links"] as const,
  scans: ["also-on", "scans"] as const,
};

export function useIdentityLinks() {
  const { user } = useAuth();
  return useQuery({
    queryKey: alsoOnKeys.links,
    enabled: !!user,
    queryFn: async (): Promise<IdentityLink[]> => {
      const { data, error } = await supabase.from("identity_links").select("*");
      if (error) throw error;
      return (data ?? []) as IdentityLink[];
    },
  });
}

export function useIdentityScans() {
  const { user } = useAuth();
  return useQuery({
    queryKey: alsoOnKeys.scans,
    enabled: !!user,
    queryFn: async (): Promise<IdentityScan[]> => {
      const { data, error } = await supabase.from("identity_scans").select("*");
      if (error) throw error;
      return (data ?? []) as IdentityScan[];
    },
  });
}

export interface ScanResult {
  total: number;
  failed: number;
  firstError: string | null;
}

// One search per person: every source they're followed through goes in the
// same request, so their name, Wikidata and Apple are looked up once.
export interface ScanJob {
  name: string;
  channelIds: string[];
}

export interface ScanProgress {
  done: number;
  total: number;
  failed: number;
  // Names of the people being searched right now.
  current: string[];
}

// Searches people two at a time and reports progress to the screen.
export function useScanSources() {
  const queryClient = useQueryClient();
  const [progress, setProgress] = useState<ScanProgress | null>(null);
  const running = useRef(false);

  const scan = useCallback(
    async (jobs: ScanJob[]): Promise<ScanResult | null> => {
      const list = jobs.filter((j) => j.channelIds.length > 0);
      if (running.current || list.length === 0) return null;
      running.current = true;
      let done = 0;
      let failed = 0;
      let firstError: string | null = null;
      const current: string[] = [];
      const report = () => setProgress({ done, total: list.length, failed, current: [...current] });
      report();
      const queue = [...list];

      const worker = async () => {
        while (queue.length) {
          const job = queue.shift()!;
          current.push(job.name);
          report();
          const { error } = await supabase.functions.invoke("find-also-on", { body: { channelIds: job.channelIds } });
          if (error) {
            failed++;
            if (!firstError) firstError = job.name + ": " + (await extractEdgeFunctionErrorMessage(error));
          }
          done++;
          current.splice(current.indexOf(job.name), 1);
          report();
          void queryClient.invalidateQueries({ queryKey: alsoOnKeys.links });
          void queryClient.invalidateQueries({ queryKey: alsoOnKeys.scans });
        }
      };

      try {
        await Promise.all([worker(), worker()]);
      } finally {
        running.current = false;
        setProgress(null);
      }
      return { total: list.length, failed, firstError };
    },
    [queryClient],
  );

  return { scan, progress, isScanning: progress !== null };
}

// "Checking Taylor Swift…", or "Checking Taylor Swift and Madonna…" when two
// run at once.
export function scanStatus(progress: ScanProgress): string {
  const names = progress.current;
  const now = names.length === 0
    ? "Finishing…"
    : names.length === 1
    ? "Checking " + names[0] + "…"
    : "Checking " + names.slice(0, -1).join(", ") + " and " + names[names.length - 1] + "…";
  return progress.total > 1 ? now + " · " + progress.done + " of " + progress.total + " people done" : now;
}

// "Same person" / "Not them". channelIds are all the sources of this person
// (the same account followed in several agents): the answer is saved on every
// copy of the match, so no copy keeps asking. Same as the web app.
export function useDecideLink() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ link, same, channelIds }: { link: IdentityLink; same: boolean; channelIds?: string[] }) => {
      const ids = [...new Set([link.channel_id, ...(channelIds ?? [])])];
      const { error } = await supabase
        .from("identity_links")
        .update(
          same
            ? { status: "confirmed", method: "user", evidence: "You confirmed this match.", decided_by_user: true }
            : { status: "rejected", decided_by_user: true },
        )
        .eq("match_key", link.match_key)
        .in("channel_id", ids);
      if (error) throw error;
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: alsoOnKeys.links });
    },
  });
}

// Combines two cards into one person, for when the same person was added twice
// under names the search couldn't tie together. Saved as a match the user
// confirmed, so it also holds after a new search. Same as the web app.
export function useMergePeople() {
  const queryClient = useQueryClient();
  const { user } = useAuth();
  return useMutation({
    mutationFn: async ({ into, other }: { into: Person; other: Person }) => {
      if (!user) throw new Error(i18n.t("errors.signedOut"));
      const row = mergeLinkRow(into, other, user.id);
      if (!row) throw new Error(i18n.t("alsoOn.cantCombine"));
      const { error } = await supabase.from("identity_links").upsert(row, { onConflict: "channel_id,match_key" });
      if (error) throw error;
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: alsoOnKeys.links });
    },
  });
}

// Undoes "Combine": every card combined into this one becomes its own card again.
export function useSeparatePerson() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ person }: { person: Person }) => {
      const { error } = await supabase
        .from("identity_links")
        .delete()
        .in("channel_id", person.sources.map((c) => c.id))
        .like("match_key", MERGE_KEY_PREFIX + "%");
      if (error) throw error;
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: alsoOnKeys.links });
    },
  });
}

// Adds a found account to an agent the same way the agent screen's Add Source
// does, through add-source (YouTube too, so it has its name and picture).
export function useFollowAccount() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ platform, url, agentId }: { platform: Platform; url: string; agentId: string }) => {
      const { data, error } = await supabase.functions.invoke("add-source", {
        body: { agentId, platform, value: url, priority: 3 },
      });
      if (error) throw new Error(await extractEdgeFunctionErrorMessage(error));
      if (!data?.channel) throw new Error(data?.error ?? i18n.t("errors.addAccountFailed"));
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ["channels"] });
      void queryClient.invalidateQueries({ queryKey: ["agents"] });
    },
  });
}
