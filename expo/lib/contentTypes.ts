// Which kinds of posts a collection keeps, per platform. Stored in
// agents.content_types: a key set to false leaves that kind out, anything
// missing is kept. YouTube Shorts and live videos use include_shorts and
// include_live. run-agent applies these. Keep in sync with
// src/lib/contentTypes.ts (web) and ios/MyFeeds/Models/ContentTypes.swift.
import type { Platform } from "@/lib/platforms";
import i18n from "@/lib/i18n";

export interface ContentTypeOption {
  key: string;
  label: string;
  help: string;
}

export const CONTENT_TYPE_GROUPS: { platform: Platform; options: ContentTypeOption[] }[] = [
  {
    platform: "instagram",
    options: [
      { key: "instagram_reels", label: "Reels", help: "Short videos" },
      { key: "instagram_posts", label: "Photo and carousel posts", help: "Single photos and multi-photo posts" },
    ],
  },
  {
    platform: "tiktok",
    options: [
      { key: "tiktok_videos", label: "Videos", help: "Regular TikTok videos" },
      { key: "tiktok_photos", label: "Photo slideshows", help: "Posts made of photos" },
    ],
  },
  {
    platform: "facebook",
    options: [
      { key: "facebook_videos", label: "Videos and reels", help: "Includes saved live videos" },
      { key: "facebook_posts", label: "Photo and text posts", help: "Everything without a video" },
    ],
  },
];

export type ContentTypes = Record<string, boolean>;

export const isContentTypeOn = (types: ContentTypes | null | undefined, key: string) => types?.[key] !== false;

/** Only the kinds that are switched off are stored. */
export function withContentType(types: ContentTypes | null | undefined, key: string, on: boolean): ContentTypes {
  const next = { ...(types ?? {}) };
  if (on) delete next[key];
  else next[key] = false;
  return next;
}

/** Label and help for a content type in the active language. */
export function contentTypeText(option: ContentTypeOption): { label: string; help: string } {
  const label = `contentTypes.${option.key}.label`;
  const help = `contentTypes.${option.key}.help`;
  return {
    label: i18n.exists(label) ? i18n.t(label as never) : option.label,
    help: i18n.exists(help) ? i18n.t(help as never) : option.help,
  };
}

export function liveNote(): string {
  return i18n.t("contentTypes.liveNote");
}
