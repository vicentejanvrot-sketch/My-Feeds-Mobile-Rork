import { supabase } from "@/lib/supabase";

// Instagram signs every photo and video link with an expiry time (the oe
// parameter, a hex Unix time), usually 2 to 3 days after the post was saved.
// After that its CDN refuses the link and the video won't play. These helpers
// spot expired links and ask the refresh-media function for new ones.
// Same logic on the web (src/lib/expiredMedia.ts) and iOS (ExpiredMedia.swift).

// Links that expire within this long count as expired, so a video doesn't stop part way.
const MARGIN_MS = 10 * 60 * 1000;

// When a link stops working (ms), from the Instagram link's oe parameter, also
// when it sits encoded inside our media-proxy link. null: no expiry. Parsed
// with a regex: URL isn't fully implemented in every React Native runtime.
export function linkExpiresAt(raw: string | null | undefined): number | null {
  if (!raw) return null;
  let text = raw;
  try {
    text = decodeURIComponent(raw);
  } catch {
    // keep it as it is
  }
  const m = /[?&]oe=([0-9a-fA-F]+)/.exec(text);
  return m ? parseInt(m[1], 16) * 1000 : null;
}

type MediaLinks = { url?: string | null; video_url?: string | null }[] | null | undefined;

export function hasExpiredMedia(media: MediaLinks): boolean {
  if (!Array.isArray(media)) return false;
  const limit = Date.now() + MARGIN_MS;
  return media.some((m) =>
    [m?.url, m?.video_url].some((u) => {
      const at = linkExpiresAt(u);
      return at !== null && at < limit;
    }),
  );
}

// An Instagram item with expired links gets new ones (saved on the item for
// every device). Anything else, or a failed renewal, comes back unchanged.
export async function withFreshMedia<T extends { id: string; platform?: string | null; media?: any; thumbnail_url?: string | null }>(
  item: T,
): Promise<T> {
  if (item.platform !== "instagram" || !hasExpiredMedia(item.media)) return item;
  try {
    const { data, error } = await supabase.functions.invoke("refresh-media", { body: { itemId: item.id } });
    if (error || !data?.refreshed || !Array.isArray(data.media)) return item;
    return { ...item, media: data.media, thumbnail_url: data.thumbnail_url ?? item.thumbnail_url };
  } catch {
    return item;
  }
}
