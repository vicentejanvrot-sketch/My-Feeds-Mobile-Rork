import createContextHook from "@nkzw/create-context-hook";
import { useState, useEffect, useCallback, useRef } from "react";
import * as WebBrowser from "expo-web-browser";
import * as Linking from "expo-linking";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { supabase } from "@/lib/supabase";
import { useAuth } from "@/lib/auth-provider";
import { useToast } from "@/components/Toast";

// ── Types ──────────────────────────────────────────────────────────

export type YouTubeStatus = "loading" | "connected" | "disconnected";

export interface YouTubeConnectionState {
  status: YouTubeStatus;
  channelName: string | null;
  channelThumbnail: string | null;
  error: string | null;
  connect: () => Promise<void>;
  disconnect: () => Promise<void>;
  syncAction: (videoId: string, action: YouTubeAction) => Promise<void>;
}

export type YouTubeAction = "rate" | "watch_later" | "unwatch_later";

const STORAGE_KEY = "@youtube/connection";

// The single OAuth redirect URI registered on the Google OAuth client.
// Google sends the user to the web app's callback page, which sees the
// "app|" state and bounces the code back into this app via APP_RETURN_URL.
const REDIRECT = "https://webapp.myfeeds.ca/youtube-auth-callback";

// Deep link the web callback page sends the code back to
// (rork-app://youtube-auth in builds, exp://.../--/youtube-auth in dev).
const APP_RETURN_URL = Linking.createURL("youtube-auth");

// ── Context Hook ───────────────────────────────────────────────────

export const [YouTubeConnectionProvider, useYouTubeConnection] =
  createContextHook((): YouTubeConnectionState => {
    const { user } = useAuth();
    const showFn = useToast();
    const toastRef = useRef(showFn);
    toastRef.current = showFn;
    const notify = (msg: string, type: "success" | "error" | "info") =>
      toastRef.current?.(msg, type);

    const [status, setStatus] = useState<YouTubeStatus>("loading");
    const [channelName, setChannelName] = useState<string | null>(null);
    const [channelThumbnail, setChannelThumbnail] = useState<string | null>(null);
    const [error, setError] = useState<string | null>(null);
    const connectingRef = useRef(false);

    // ── Restore persisted connection on mount / user change ────────

    useEffect(() => {
      if (!user) {
        setStatus("disconnected");
        setChannelName(null);
        setChannelThumbnail(null);
        return;
      }

      AsyncStorage.getItem(STORAGE_KEY)
        .then((stored) => {
          if (stored) {
            try {
              const parsed = JSON.parse(stored);
              if (parsed.channelName || parsed.email) {
                setChannelName(parsed.channelName ?? parsed.email);
                setChannelThumbnail(parsed.channelThumbnail ?? null);
                setStatus("connected");
                return;
              }
            } catch {
              // corrupt storage — treat as disconnected
            }
          }
          setStatus("disconnected");
        })
        .catch(() => setStatus("disconnected"));
    }, [user]);

    // ── Connect ─────────────────────────────────────────────────

    const connect = useCallback(async () => {
      if (connectingRef.current) return;
      connectingRef.current = true;
      setError(null);

      try {
        // 1. Ask the edge function for the Google OAuth URL. appReturnUrl tells
        //    the web callback page to send the code back into this app.
        const { data: authData, error: authError } = await supabase.functions.invoke(
          "youtube-auth",
          { body: { appReturnUrl: APP_RETURN_URL } },
        );

        if (authError) {
          throw new Error(
            authError.message || JSON.stringify(authError) || "Failed to start authentication"
          );
        }

        const raw: Record<string, any> | undefined = authData as any;
        const authUrl: string | undefined =
          raw?.authUrl ?? raw?.url ?? raw?.data?.authUrl ?? raw?.data?.url ?? undefined;

        if (!authUrl) {
          const debugInfo = raw ? JSON.stringify(raw).slice(0, 200) : "(empty response)";
          throw new Error(`No authorization URL returned from server. Response: ${debugInfo}`);
        }

        // 2. Open the in-app browser. Google -> web callback page -> APP_RETURN_URL,
        //    which openAuthSessionAsync catches and resolves with.
        const result = await WebBrowser.openAuthSessionAsync(authUrl, APP_RETURN_URL);

        if (result.type === "cancel" || result.type === "dismiss") {
          notify("YouTube connection cancelled", "info");
          return;
        }

        if (result.type !== "success" || !result.url) {
          setError("Authentication failed — unexpected browser response");
          notify("Authentication failed — unexpected browser response", "error");
          return;
        }

        // 3. Read the authorization code from the deep link
        const { queryParams } = Linking.parse(result.url);
        const code = typeof queryParams?.code === "string" ? queryParams.code : null;
        const errorParam = typeof queryParams?.error === "string" ? queryParams.error : null;

        if (errorParam) {
          throw new Error(
            errorParam === "access_denied" ? "YouTube access was denied" : errorParam
          );
        }

        if (!code) {
          throw new Error("No authorization code received");
        }

        // 4. Exchange the code for tokens (server-side)
        const { data: callbackData, error: callbackError } =
          await supabase.functions.invoke("youtube-auth-callback", {
            body: { code, redirectUri: REDIRECT },
          });

        if (callbackError) {
          throw new Error(callbackError.message || "Failed to complete authentication");
        }

        // 5. Pull account info from the response
        const cb = (callbackData as any) ?? {};
        const channel = cb.channel;
        const name: string | null =
          channel?.name || channel?.title || cb.name || cb.email || null;
        const thumbnail: string | null = channel?.thumbnail || cb.picture || null;

        setChannelName(name);
        setChannelThumbnail(thumbnail);
        setStatus("connected");
        setError(null);

        // 6. Persist so the app remembers the connection across launches
        await AsyncStorage.setItem(
          STORAGE_KEY,
          JSON.stringify({
            channelName: name,
            channelThumbnail: thumbnail,
            email: cb.email ?? null,
            accessToken: cb.access_token ?? null,
            refreshToken: cb.refresh_token ?? null,
            expiresAt: cb.expires_in ? Date.now() + cb.expires_in * 1000 : null,
          }),
        );

        notify("YouTube connected", "success");
      } catch (err: any) {
        const message = err?.message ?? "Connection failed";
        setError(message);
        notify(message, "error");
      } finally {
        connectingRef.current = false;
      }
    }, []);

    // ── Disconnect ──────────────────────────────────────────────

    const disconnect = useCallback(async () => {
      try {
        const { error: disconnectError } = await supabase.functions.invoke(
          "youtube-api",
          { body: { action: "disconnect" } },
        );

        if (disconnectError) {
          throw new Error(disconnectError.message || "Failed to disconnect");
        }

        setStatus("disconnected");
        setChannelName(null);
        setChannelThumbnail(null);
        setError(null);
        await AsyncStorage.removeItem(STORAGE_KEY);
        notify("YouTube disconnected", "success");
      } catch (err: any) {
        notify(err?.message ?? "Failed to disconnect", "error");
      }
    }, []);

    // ── Sync a video action to YouTube ──────────────────────────

    const syncAction = useCallback(
      async (videoId: string, action: YouTubeAction) => {
        if (status !== "connected") return;
        try {
          const { error: syncError } = await supabase.functions.invoke(
            "youtube-api",
            { body: { action, videoId } },
          );
          if (syncError) {
            console.warn("[youtube-sync] Failed:", syncError.message);
          }
        } catch (err: any) {
          console.warn("[youtube-sync] Failed:", err?.message);
        }
      },
      [status],
    );

    return {
      status,
      channelName,
      channelThumbnail,
      error,
      connect,
      disconnect,
      syncAction,
    };
  });
