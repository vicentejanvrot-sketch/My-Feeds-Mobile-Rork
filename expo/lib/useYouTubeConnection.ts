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
  connecting: boolean;
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

// YouTube no longer lets apps write to the real Watch Later list, so
// "Save to YouTube" goes into this private playlist (created on first use).
const SAVE_PLAYLIST_TITLE = "My Feeds - Watch Later";

interface StoredConnection {
  channelName?: string | null;
  channelThumbnail?: string | null;
  email?: string | null;
  accessToken?: string | null;
  refreshToken?: string | null;
  expiresAt?: number | null;
  savePlaylistId?: string | null;
}

async function readStored(): Promise<StoredConnection | null> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as StoredConnection) : null;
  } catch {
    return null;
  }
}

async function writeStored(patch: StoredConnection): Promise<void> {
  const current = (await readStored()) ?? {};
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify({ ...current, ...patch }));
}

// Calls the web app's youtube-api edge function and throws on any error.
async function callYouTubeApi<T = any>(body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke("youtube-api", { body });
  if (error) {
    // Non-2xx responses carry the real message in the response body.
    let message = error.message || "YouTube request failed";
    try {
      const ctx = (error as any).context;
      if (ctx && typeof ctx.json === "function") {
        const payload = await ctx.json();
        if (payload?.error) message = payload.error;
      }
    } catch {
      // keep the generic message
    }
    throw new Error(message);
  }
  if ((data as any)?.error) throw new Error((data as any).error);
  return data as T;
}

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
    const [connecting, setConnecting] = useState(false);
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
      setConnecting(true);
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
        setConnecting(false);
      }
    }, []);

    // ── Access token (refreshed when close to expiry) ───────────

    const getAccessToken = useCallback(async (): Promise<string> => {
      const stored = await readStored();
      if (!stored?.accessToken) {
        throw new Error("Reconnect YouTube to use this");
      }
      const expiresAt = stored.expiresAt ?? 0;
      if (expiresAt > Date.now() + 5 * 60 * 1000) {
        return stored.accessToken;
      }
      if (!stored.refreshToken) {
        throw new Error("YouTube session expired — reconnect YouTube");
      }
      const refreshed = await callYouTubeApi<{ access_token: string; expires_in: number }>({
        action: "refresh",
        refreshToken: stored.refreshToken,
      });
      await writeStored({
        accessToken: refreshed.access_token,
        expiresAt: Date.now() + (refreshed.expires_in ?? 3600) * 1000,
      });
      return refreshed.access_token;
    }, []);

    // Find or create the private playlist "Save to YouTube" writes into.
    const getSavePlaylistId = useCallback(async (accessToken: string): Promise<string> => {
      const stored = await readStored();
      if (stored?.savePlaylistId) return stored.savePlaylistId;

      const { playlists } = await callYouTubeApi<{ playlists: { id: string; title: string }[] }>({
        action: "get_playlists",
        accessToken,
      });
      let id = playlists?.find((p) => p.title === SAVE_PLAYLIST_TITLE)?.id;
      if (!id) {
        const created = await callYouTubeApi<{ playlist: { id: string } }>({
          action: "create_playlist",
          accessToken,
          playlistTitle: SAVE_PLAYLIST_TITLE,
        });
        id = created.playlist.id;
      }
      await writeStored({ savePlaylistId: id });
      return id;
    }, []);

    // ── Disconnect ──────────────────────────────────────────────

    const disconnect = useCallback(async () => {
      // Tokens only live on this device, so disconnecting is local.
      setStatus("disconnected");
      setChannelName(null);
      setChannelThumbnail(null);
      setError(null);
      await AsyncStorage.removeItem(STORAGE_KEY).catch(() => {});
      notify("YouTube disconnected", "success");
    }, []);

    // ── Sync a video action to YouTube ──────────────────────────
    // Throws on failure so the caller can show the right toast.

    const syncAction = useCallback(
      async (videoId: string, action: YouTubeAction) => {
        if (status !== "connected") throw new Error("YouTube is not connected");
        const accessToken = await getAccessToken();

        if (action === "rate") {
          await callYouTubeApi({ action: "rate_video", accessToken, videoId, rating: "like" });
          return;
        }

        if (action === "watch_later") {
          const playlistId = await getSavePlaylistId(accessToken);
          try {
            await callYouTubeApi({ action: "add_to_playlist", accessToken, videoId, playlistId });
          } catch (err: any) {
            // Playlist was deleted on YouTube — forget it and create a fresh one.
            if (/not ?found/i.test(err?.message ?? "")) {
              await writeStored({ savePlaylistId: null });
              const freshId = await getSavePlaylistId(accessToken);
              await callYouTubeApi({ action: "add_to_playlist", accessToken, videoId, playlistId: freshId });
              return;
            }
            throw err;
          }
          return;
        }

        // "unwatch_later" has no YouTube API equivalent; nothing to do.
      },
      [status, getAccessToken, getSavePlaylistId],
    );

    return {
      status,
      channelName,
      channelThumbnail,
      error,
      connecting,
      connect,
      disconnect,
      syncAction,
    };
  });
