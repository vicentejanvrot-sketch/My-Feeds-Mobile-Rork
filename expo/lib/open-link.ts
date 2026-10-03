import { Linking, Platform } from "react-native";
import { router } from "expo-router";

/**
 * Open an external URL.
 *
 * On web, http/https links open in a new browser tab (with noopener for
 * security) so the user never loses the running SPA. Other schemes (mailto:,
 * tel:, app deep links) and all native platforms fall through to Linking.
 */
export async function openExternalLink(url: string): Promise<void> {
  if (!url) return;
  if (
    Platform.OS === "web" &&
    typeof window !== "undefined" &&
    /^https?:\/\//i.test(url)
  ) {
    window.open(url, "_blank", "noopener,noreferrer");
    return;
  }
  await Linking.openURL(url);
}

/**
 * A private account's profile (Instagram, TikTok, X, Facebook), opened inside
 * My Feeds: its posts can't be fetched, so the user reads them in an in-app
 * browser where they're signed in on this phone. On web it opens a new tab.
 */
export function openPrivateProfile(args: { url: string; name?: string | null; platformLabel?: string | null }): void {
  if (!args.url) return;
  if (Platform.OS === "web") {
    void openExternalLink(args.url);
    return;
  }
  router.push({
    pathname: "/profile-viewer",
    params: { url: args.url, name: args.name ?? "", platform: args.platformLabel ?? "" },
  });
}
