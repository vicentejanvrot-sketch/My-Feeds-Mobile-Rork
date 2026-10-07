// Apple Music "Add to playlist": adds a release's songs to the user's "My Feeds"
// playlist in their Apple Music library. The songs stay in Apple Music, so the
// user listens there (and can download them for offline in the Apple Music app).
//
// Sign-in: Apple's MusicKit sign-in only runs in a browser, so the app opens
// the web app's /apple-music-connect page in the phone's browser (same way as
// the YouTube connection). It sends the Music User Token back through
// APP_RETURN_URL. The token is kept in the phone's secure storage. The playlist
// id is saved on the account ("apple_music_playlist_id"), the same key the web
// and iOS apps use, so every device adds to the same playlist.
import * as Linking from "expo-linking";
import * as SecureStore from "expo-secure-store";
import * as WebBrowser from "expo-web-browser";
import { Platform } from "react-native";
import { supabase } from "@/lib/supabase";
import i18n from "@/lib/i18n";

const CONNECT_PAGE = "https://webapp.myfeeds.ca/apple-music-connect";
const APP_RETURN_URL = Linking.createURL("apple-music-auth");
const TOKEN_KEY = "appleMusicUserToken";
export const PLAYLIST_KEY = "apple_music_playlist_id";

export const appleMusicSupported = Platform.OS !== "web";

export class AppleMusicError extends Error {
  constructor(message: string, public code?: string) {
    super(message);
  }
}

async function errorFrom(error: unknown, data: unknown): Promise<AppleMusicError> {
  let body = data as { error?: string; code?: string } | null;
  try {
    const ctx = (error as { context?: { json?: () => Promise<unknown> } } | null)?.context;
    if (ctx && typeof ctx.json === "function") body = (await ctx.json()) as { error?: string; code?: string };
  } catch {
    // keep what we have
  }
  return new AppleMusicError(body?.error || (error instanceof Error ? error.message : i18n.t("appleMusic.requestFailed")), body?.code);
}

async function getDeveloperToken(): Promise<string> {
  const { data, error } = await supabase.functions.invoke("apple-music", { body: { action: "developer-token" } });
  if (error || !data?.token) throw await errorFrom(error, data);
  return data.token as string;
}

export async function forgetAppleMusic() {
  await SecureStore.deleteItemAsync(TOKEN_KEY).catch(() => undefined);
}

/** Opens Apple's sign-in in the phone's browser and keeps the token it returns. */
export async function connectAppleMusic(): Promise<string> {
  if (!appleMusicSupported) throw new AppleMusicError(i18n.t("appleMusic.nativeOnly"));
  const developerToken = await getDeveloperToken();
  const url = `${CONNECT_PAGE}#dt=${encodeURIComponent(developerToken)}&return=${encodeURIComponent(APP_RETURN_URL)}`;
  const result = await WebBrowser.openAuthSessionAsync(url, APP_RETURN_URL);
  if (result.type !== "success" || !result.url) throw new AppleMusicError(i18n.t("appleMusic.notAllowed"), "cancelled");
  const { queryParams } = Linking.parse(result.url);
  const token = typeof queryParams?.token === "string" ? queryParams.token : null;
  if (!token) throw new AppleMusicError(i18n.t("appleMusic.notAllowed"), "cancelled");
  await SecureStore.setItemAsync(TOKEN_KEY, token);
  return token;
}

async function savedPlaylistId(): Promise<string | null> {
  const { data } = await supabase.auth.getUser();
  const value = data.user?.user_metadata?.[PLAYLIST_KEY];
  return typeof value === "string" && value ? value : null;
}

/**
 * Adds every song of an Apple Music release to the "My Feeds" playlist.
 * albumId: the release's Apple id (items.video_id "apple_music:<id>" works too).
 */
export async function addReleaseToAppleMusic(albumId: string): Promise<{ added: number }> {
  let userToken = await SecureStore.getItemAsync(TOKEN_KEY).catch(() => null);
  if (!userToken) userToken = await connectAppleMusic();

  const attempt = async (token: string) => {
    const playlistId = await savedPlaylistId();
    const { data, error } = await supabase.functions.invoke("apple-music", {
      body: { action: "add", userToken: token, albumId, playlistId },
    });
    if (error || !data?.playlistId) throw await errorFrom(error, data);
    if (data.playlistId !== playlistId) {
      await supabase.auth.updateUser({ data: { [PLAYLIST_KEY]: data.playlistId } });
    }
    return { added: Number(data.added) || 0 };
  };

  try {
    return await attempt(userToken);
  } catch (e) {
    // Access expired: sign in again once, then retry.
    if (e instanceof AppleMusicError && e.code === "reconnect") {
      await forgetAppleMusic();
      return attempt(await connectAppleMusic());
    }
    throw e;
  }
}
