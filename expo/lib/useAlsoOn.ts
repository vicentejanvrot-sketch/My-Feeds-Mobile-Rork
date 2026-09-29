// Data for the Following screen: identity links and scans, running scans,
// Same person / Not them, and following a found account. Same behaviour as
// src/hooks/useAlsoOn.ts on the web.
import { useCallback, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/lib/auth-provider";
import { extractEdgeFunctionErrorMessage } from "@/lib/hooks";
import type { Platform } from "@/lib/platforms";
import type { IdentityLink, IdentityScan } from "@/lib/alsoOn";

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

// Checks sources two at a time and reports progress to the screen.
export function useScanSources() {
  const queryClient = useQueryClient();
  const [progress, setProgress] = useState<{ done: number; total: number; failed: number } | null>(null);
  const running = useRef(false);

  const scan = useCallback(
    async (channelIds: string[]): Promise<ScanResult | null> => {
      if (running.current || channelIds.length === 0) return null;
      running.current = true;
      let done = 0;
      let failed = 0;
      let firstError: string | null = null;
      setProgress({ done, total: channelIds.length, failed });
      const queue = [...channelIds];

      const worker = async () => {
        while (queue.length) {
          const channelId = queue.shift()!;
          const { error } = await supabase.functions.invoke("find-also-on", { body: { channelId } });
          if (error) {
            failed++;
            if (!firstError) firstError = await extractEdgeFunctionErrorMessage(error);
          }
          done++;
          setProgress({ done, total: channelIds.length, failed });
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
      return { total: channelIds.length, failed, firstError };
    },
    [queryClient],
  );

  return { scan, progress, isScanning: progress !== null };
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

// Adds a found account to an agent the same way the agent screen's Add Source
// does: YouTube as a channel row, everything else through add-source.
export function useFollowAccount() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async ({ platform, url, agentId }: { platform: Platform; url: string; agentId: string }) => {
      if (platform === "youtube") {
        const { error } = await supabase.from("channels").insert({ agent_id: agentId, channel_url: url, priority: 3 });
        if (error) throw error;
        return;
      }
      const { data, error } = await supabase.functions.invoke("add-source", {
        body: { agentId, platform, value: url, priority: 3 },
      });
      if (error) throw new Error(await extractEdgeFunctionErrorMessage(error));
      if (!data?.channel) throw new Error(data?.error ?? "Couldn't add that account.");
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ["channels"] });
      void queryClient.invalidateQueries({ queryKey: ["agents"] });
    },
  });
}
