import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import * as WebBrowser from "expo-web-browser";
import * as Linking from "expo-linking";
import { supabase } from "@/lib/supabase";
import { extractEdgeFunctionErrorMessage } from "@/lib/hooks";
import i18n from "@/lib/i18n";

// GitHub and Reddit accounts the user connected (account-connect function),
// so adding a GitHub or Reddit account on People also follows it there. Same
// as src/hooks/useConnections.ts on the web. YouTube has its own connection
// (useYouTubeConnection).

export type ConnectProvider = "github" | "reddit";

export const CONNECT_PROVIDERS: ConnectProvider[] = ["github", "reddit"];

export const CONNECT_LABEL: Record<ConnectProvider, string> = { github: "GitHub", reddit: "Reddit" };

export interface Connection {
  provider: ConnectProvider;
  accountName: string | null;
  avatar: string | null;
}

// GitHub / Reddit -> the web /connect-callback page -> this deep link
// (rork-app://connect-auth in builds, exp://.../--/connect-auth in dev), which
// openAuthSessionAsync catches.
const APP_RETURN_URL = Linking.createURL("connect-auth");

export class ConnectError extends Error {
  constructor(message: string, public code?: string) {
    super(message);
  }
}

async function call<T extends { error?: string; code?: string }>(body: Record<string, unknown>, fallback: string): Promise<T> {
  const { data, error } = await supabase.functions.invoke("account-connect", { body });
  if (error) throw new ConnectError(await extractEdgeFunctionErrorMessage(error));
  const reply = (data ?? null) as T | null;
  if (!reply) throw new ConnectError(fallback);
  if (reply.error) throw new ConnectError(reply.error, reply.code);
  return reply;
}

export function isConnectProvider(platform: string): platform is ConnectProvider {
  return platform === "github" || platform === "reddit";
}

export function useConnections() {
  return useQuery({
    queryKey: ["connections"],
    queryFn: async (): Promise<Connection[]> => {
      const data = await call<{ connections?: Connection[]; error?: string }>({ action: "list" }, i18n.t("connections.loadFailed"));
      return data.connections ?? [];
    },
    staleTime: 60_000,
  });
}

// Opens the GitHub or Reddit sign-in in the in-app browser and finishes the
// connection when it comes back. Resolves to the connection, or null when the
// user closed the browser.
export function useConnect() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (provider: ConnectProvider): Promise<Connection | null> => {
      const start = await call<{ authUrl?: string; error?: string }>(
        { action: "start", provider, appReturnUrl: APP_RETURN_URL },
        i18n.t("connections.openFailed", { provider: CONNECT_LABEL[provider] }),
      );
      if (!start.authUrl) throw new ConnectError(i18n.t("connections.openFailed", { provider: CONNECT_LABEL[provider] }));
      const result = await WebBrowser.openAuthSessionAsync(start.authUrl, APP_RETURN_URL);
      if (result.type !== "success" || !result.url) return null;
      const { queryParams } = Linking.parse(result.url);
      const code = typeof queryParams?.code === "string" ? queryParams.code : null;
      const state = typeof queryParams?.state === "string" ? queryParams.state : null;
      const errorParam = typeof queryParams?.error === "string" ? queryParams.error : null;
      if (errorParam === "access_denied") return null;
      if (!code || !state) throw new ConnectError(i18n.t("connections.signInUnfinished", { provider: CONNECT_LABEL[provider] }));
      const done = await call<{ provider?: ConnectProvider; accountName?: string | null; avatar?: string | null; error?: string }>(
        { action: "finish", code, state },
        i18n.t("connections.connectFailed", { provider: CONNECT_LABEL[provider] }),
      );
      return { provider, accountName: done.accountName ?? null, avatar: done.avatar ?? null };
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ["connections"] });
    },
  });
}

export function useDisconnect() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (provider: ConnectProvider) => {
      await call({ action: "disconnect", provider }, i18n.t("connections.disconnectFailed", { provider: CONNECT_LABEL[provider] }));
    },
    onSettled: () => {
      void queryClient.invalidateQueries({ queryKey: ["connections"] });
    },
  });
}

// Follows a GitHub or Reddit account with the user's connected account.
export async function followOnPlatform(provider: ConnectProvider, url: string): Promise<{ already: boolean }> {
  const data = await call<{ ok?: boolean; already?: boolean; error?: string }>(
    { action: "follow", provider, url },
    i18n.t("connections.followFailed", { provider: CONNECT_LABEL[provider] }),
  );
  return { already: data.already === true };
}
