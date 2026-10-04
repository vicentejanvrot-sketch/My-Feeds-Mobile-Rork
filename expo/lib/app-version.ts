// Which app version this phone runs, saved to the app_installs table when the
// app opens (one row per phone), and whether a newer one is in the store
// (app_releases: latest_version shows "Update available", min_version blocks
// older versions until updated). On iOS the App Store itself is asked too.
// Same as the iOS app (AppVersionService.swift).
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Application from "expo-application";
import { Platform } from "react-native";
import { supabase } from "@/lib/supabase";

const DEVICE_KEY = "app.deviceId";
const APP_STORE_ID = "6778948617";

export type StorePlatform = "ios" | "android";

export const storePlatform: StorePlatform | null =
  Platform.OS === "ios" ? "ios" : Platform.OS === "android" ? "android" : null;

/** The version people see in the store, e.g. "1.0.11". */
export const appVersion: string | null = Application.nativeApplicationVersion ?? null;

/** -1 when a is older than b, 0 when equal, 1 when newer. "1.0.10" is newer than "1.0.9". */
export function compareVersions(a: string, b: string): number {
  const pa = a.split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0) return d < 0 ? -1 : 1;
  }
  return 0;
}

/** A random id kept on this phone, so each phone is one row. */
async function deviceId(): Promise<string> {
  const saved = await AsyncStorage.getItem(DEVICE_KEY).catch(() => null);
  if (saved) return saved;
  const id = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
  await AsyncStorage.setItem(DEVICE_KEY, id).catch(() => undefined);
  return id;
}

/** Saves this phone's app version for the signed-in user. Best effort. */
export async function reportInstall(userId: string): Promise<void> {
  if (!storePlatform || !appVersion) return;
  try {
    const now = new Date().toISOString();
    await supabase.from("app_installs").upsert(
      {
        user_id: userId,
        device_id: await deviceId(),
        platform: storePlatform,
        app_version: appVersion,
        build: Application.nativeBuildVersion ?? null,
        os_version: `${Platform.OS} ${Platform.Version}`,
        device_model: null,
        last_seen_at: now,
      },
      { onConflict: "user_id,device_id" },
    );
  } catch {
    // Not having this row never stops the app.
  }
}

export interface UpdateInfo {
  latestVersion: string;
  storeUrl: string;
  /** This version is below the minimum: the app can't be used until updated. */
  required: boolean;
}

/** A newer version than this one, or null when the app is up to date. */
export async function checkForUpdate(): Promise<UpdateInfo | null> {
  if (!storePlatform || !appVersion) return null;
  let latest: string | null = null;
  let minimum: string | null = null;
  let storeUrl: string | null = null;
  try {
    const { data } = await supabase
      .from("app_releases")
      .select("latest_version, min_version, store_url")
      .eq("platform", storePlatform)
      .maybeSingle();
    if (data) {
      latest = data.latest_version ?? null;
      minimum = data.min_version ?? null;
      storeUrl = data.store_url ?? null;
    }
  } catch {
    // Use what the store says below.
  }
  if (storePlatform === "ios") {
    try {
      const res = await fetch(`https://itunes.apple.com/lookup?id=${APP_STORE_ID}&t=${Date.now()}`);
      const json = await res.json();
      const store = json?.results?.[0];
      if (typeof store?.version === "string" && (!latest || compareVersions(store.version, latest) > 0)) latest = store.version;
      if (!storeUrl && typeof store?.trackViewUrl === "string") storeUrl = store.trackViewUrl;
    } catch {
      // Offline: no banner.
    }
  }
  if (!latest || !storeUrl) return null;
  const required = !!minimum && compareVersions(appVersion, minimum) < 0;
  if (!required && compareVersions(appVersion, latest) >= 0) return null;
  return { latestVersion: latest, storeUrl, required };
}
