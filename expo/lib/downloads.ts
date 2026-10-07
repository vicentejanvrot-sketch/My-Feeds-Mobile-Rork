// Offline downloads: keeps an item on the phone so it can be read or played
// with no connection (plane, road trip). What's kept: the text, the AI summary,
// photos and cover art, full podcast episodes, and post videos (X, Instagram,
// Facebook, LinkedIn, Reddit). YouTube videos can't be downloaded: YouTube only
// allows its own player, so they still need a connection.
//
// Layout on the phone, under the app's Documents folder:
//   downloads/index.json          list of downloads (DownloadEntry)
//   downloads/<itemId>/item.json  the item, with "local:<file>" in place of links
//   downloads/<itemId>/<files>    thumb, media-0, audio, player.html,
//                                 video-0.mp4 (+ video-0-audio.mp4 for Reddit), video-0.html
// Links are saved as "local:<file>" and resolved on read, because the Documents
// folder's full path changes when iOS updates the app.
import * as FileSystem from "expo-file-system/legacy";
import { Platform } from "react-native";
import { create } from "zustand";
import { supabase } from "@/lib/supabase";
import { withFreshMedia } from "@/lib/expired-media";
import type { ItemWithAnalysis } from "@/lib/database";
import i18n from "@/lib/i18n";

export interface DownloadEntry {
  itemId: string;
  title: string | null;
  platform: string | null;
  channelName: string | null;
  /** File name inside the item's folder, or null. */
  thumbFile: string | null;
  savedAt: string;
  bytes: number;
  hasAudio: boolean;
}

type MediaEntry = Record<string, unknown> & {
  type?: string;
  url?: string;
  image?: string | null;
  audio_url?: string | null;
  video_url?: string | null;
  hls_url?: string | null;
  /** Saved copy only: the page that plays the downloaded video (see videoPlayerHtml). */
  local_player?: string | null;
};

const LOCAL = "local:";
const ROOT = FileSystem.documentDirectory ? `${FileSystem.documentDirectory}downloads/` : null;
const INDEX = ROOT ? `${ROOT}index.json` : null;

/** Downloads work in the iOS and Android apps, not in the browser. */
export const downloadsSupported = Platform.OS !== "web" && !!ROOT;

function folderName(itemId: string): string {
  return itemId.replace(/[^A-Za-z0-9_-]/g, "_");
}

export function itemFolder(itemId: string): string {
  return `${ROOT}${folderName(itemId)}/`;
}

export function localFileUri(itemId: string, file: string): string {
  return `${itemFolder(itemId)}${file}`;
}

/** Same audio page the podcast player uses online, pointing at the saved file. */
export function podcastPlayerHtml(src: string): string {
  const safe = src.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  return `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><meta name="referrer" content="no-referrer">
<style>html,body{margin:0;padding:0;background:transparent}audio{width:100%;display:block}</style></head>
<body><audio controls preload="metadata" src="${safe}"></audio></body></html>`;
}

/**
 * Page that plays a downloaded video from the phone. Reddit keeps a video's
 * sound in a separate file, so when there is one it plays alongside, kept in
 * step with the picture (play, pause, seek, speed, mute).
 */
export function videoPlayerHtml(videoFile: string, posterFile: string | null, audioFile: string | null): string {
  const esc = (v: string) => v.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  const sync = audioFile
    ? `<audio src="${esc(audioFile)}" preload="auto"></audio>
<script>(function(){var v=document.querySelector('video'),a=document.querySelector('audio');if(!v||!a)return;
function at(){if(Math.abs(a.currentTime-v.currentTime)>0.25)a.currentTime=v.currentTime}
v.addEventListener('play',function(){at();a.play().catch(function(){})});
v.addEventListener('pause',function(){a.pause()});
v.addEventListener('seeking',at);v.addEventListener('seeked',at);
v.addEventListener('waiting',function(){a.pause()});v.addEventListener('playing',function(){at();a.play().catch(function(){})});
v.addEventListener('ratechange',function(){a.playbackRate=v.playbackRate});
v.addEventListener('volumechange',function(){a.muted=v.muted;a.volume=v.volume});
v.addEventListener('ended',function(){a.pause()});
setInterval(function(){if(!v.paused)at()},1000);})();</script>`
    : "";
  return `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<style>html,body{margin:0;padding:0;background:#000;height:100%}video{width:100%;height:100%;object-fit:contain;background:#000}</style></head>
<body><video src="${esc(videoFile)}"${posterFile ? ` poster="${esc(posterFile)}"` : ""} controls playsinline webkit-playsinline preload="auto"></video>${sync}</body></html>`;
}

/** Instagram videos are stored behind our media proxy; the file itself downloads straight from Instagram's CDN. */
function directVideoSource(url: string): string {
  try {
    const parsed = new URL(url);
    if (!parsed.pathname.endsWith("/functions/v1/media-proxy")) return url;
    const inner = new URL(parsed.searchParams.get("u") ?? "");
    const host = inner.hostname.toLowerCase();
    return host.endsWith(".cdninstagram.com") || host.endsWith(".fbcdn.net") ? inner.toString() : url;
  } catch {
    return url;
  }
}

/** Reddit's MP4 has no sound; its sound sits next to it as DASH_AUDIO_128.mp4 (or older names). */
function redditAudioCandidates(videoUrl: string): string[] {
  const match = videoUrl.match(/^(https:\/\/v\.redd\.it\/[^/]+)\//i);
  if (!match) return [];
  return ["DASH_AUDIO_128.mp4", "DASH_AUDIO_64.mp4", "DASH_audio.mp4", "audio"].map((f) => `${match[1]}/${f}`);
}

function extensionOf(url: string, fallback: string): string {
  try {
    const path = new URL(url).pathname.toLowerCase();
    const match = path.match(/\.(jpe?g|png|webp|gif|heic|mp3|m4a|aac|wav|ogg)$/);
    return match ? `.${match[1]}` : fallback;
  } catch {
    return fallback;
  }
}

async function fileSize(uri: string): Promise<number> {
  try {
    const info = await FileSystem.getInfoAsync(uri);
    return info.exists && "size" in info ? info.size ?? 0 : 0;
  } catch {
    return 0;
  }
}

async function writeIndex(entries: Record<string, DownloadEntry>) {
  if (!ROOT || !INDEX) return;
  await FileSystem.makeDirectoryAsync(ROOT, { intermediates: true }).catch(() => undefined);
  await FileSystem.writeAsStringAsync(INDEX, JSON.stringify(Object.values(entries)));
}

interface DownloadsState {
  loaded: boolean;
  entries: Record<string, DownloadEntry>;
  /** 0..1 while a download is running. */
  progress: Record<string, number>;
}

export const useDownloadsStore = create<DownloadsState>(() => ({
  loaded: false,
  entries: {},
  progress: {},
}));

let loading: Promise<void> | null = null;

/** Reads the list of downloads from the phone (once). */
export function loadDownloads(): Promise<void> {
  if (!downloadsSupported || !INDEX) {
    useDownloadsStore.setState({ loaded: true });
    return Promise.resolve();
  }
  if (!loading) {
    loading = (async () => {
      let entries: Record<string, DownloadEntry> = {};
      try {
        const info = await FileSystem.getInfoAsync(INDEX);
        if (info.exists) {
          const list = JSON.parse(await FileSystem.readAsStringAsync(INDEX)) as DownloadEntry[];
          entries = Object.fromEntries(list.map((e) => [e.itemId, e]));
        }
      } catch {
        entries = {};
      }
      useDownloadsStore.setState({ loaded: true, entries });
    })();
  }
  return loading;
}

function setProgress(itemId: string, value: number | null) {
  useDownloadsStore.setState((s) => {
    const progress = { ...s.progress };
    if (value === null) delete progress[itemId];
    else progress[itemId] = value;
    return { progress };
  });
}

/**
 * Saves an item on the phone. Photos that fail are left as links; a podcast
 * episode that fails cancels the download.
 */
export async function downloadItem(itemId: string): Promise<DownloadEntry> {
  if (!downloadsSupported) throw new Error(i18n.t("downloads.unsupported"));
  await loadDownloads();
  if (useDownloadsStore.getState().progress[itemId] !== undefined) {
    throw new Error(i18n.t("downloads.already"));
  }
  setProgress(itemId, 0);
  const folder = itemFolder(itemId);
  try {
    const { data, error } = await supabase
      .from("items")
      .select("*, item_analysis(*)")
      .eq("id", itemId)
      .single();
    if (error || !data) throw new Error(i18n.t("downloads.loadFailed"));
    // Instagram's links expire a few days after the post was saved: renewed
    // first, so the photos and video actually download.
    const item = (await withFreshMedia(data as ItemWithAnalysis)) as ItemWithAnalysis;

    await FileSystem.deleteAsync(folder, { idempotent: true });
    await FileSystem.makeDirectoryAsync(folder, { intermediates: true });

    const media = ((item.media ?? []) as MediaEntry[]).map((m) => ({ ...m }));
    const audio = media.find((m) => m.type === "audio" && typeof m.audio_url === "string" && m.audio_url);
    // The post's own videos (not a quoted post's), as MP4 files.
    const videos = media
      .map((m, i) => ({ m, i }))
      .filter(({ m }) => m.type !== "quote" && m.type !== "article" && typeof m.video_url === "string" && /^https?:/i.test(m.video_url));

    // Photos and cover art first (small), then the episode (large, shows progress).
    const images: { url: string; file: string; apply: (local: string) => void }[] = [];
    let thumbFile: string | null = null;
    if (item.thumbnail_url && /^https?:/i.test(item.thumbnail_url)) {
      const file = `thumb${extensionOf(item.thumbnail_url, ".jpg")}`;
      images.push({ url: item.thumbnail_url, file, apply: (local) => { item.thumbnail_url = local; thumbFile = file; } });
    }
    media.forEach((m, i) => {
      // A quoted post or X article: its picture (the post itself is a link).
      if (m.type === "quote" || m.type === "article") {
        if (typeof m.image === "string" && /^https?:/i.test(m.image)) {
          const file = `embed-${i}${extensionOf(m.image, ".jpg")}`;
          images.push({ url: m.image, file, apply: (local) => { m.image = local; } });
        }
        return;
      }
      if (typeof m.url === "string" && /^https?:/i.test(m.url)) {
        const file = `media-${i}${extensionOf(m.url, ".jpg")}`;
        images.push({ url: m.url, file, apply: (local) => { m.url = local; } });
      }
    });

    const share = audio || videos.length ? 0.1 : 1;
    for (let i = 0; i < images.length; i++) {
      const img = images[i];
      try {
        const result = await FileSystem.downloadAsync(img.url, folder + img.file);
        if (result.status >= 200 && result.status < 300) img.apply(LOCAL + img.file);
        else await FileSystem.deleteAsync(folder + img.file, { idempotent: true });
      } catch {
        // Keep the link; the photo shows when there's a connection.
      }
      setProgress(itemId, ((i + 1) / images.length) * share);
    }

    if (audio && typeof audio.audio_url === "string") {
      const file = `audio${extensionOf(audio.audio_url, ".mp3")}`;
      const task = FileSystem.createDownloadResumable(audio.audio_url, folder + file, {}, (p) => {
        if (p.totalBytesExpectedToWrite > 0) {
          setProgress(itemId, share + (p.totalBytesWritten / p.totalBytesExpectedToWrite) * (1 - share));
        }
      });
      const result = await task.downloadAsync();
      if (!result || result.status < 200 || result.status >= 300) {
        throw new Error(i18n.t("downloads.episodeFailed"));
      }
      audio.audio_url = LOCAL + file;
      await FileSystem.writeAsStringAsync(folder + "player.html", podcastPlayerHtml(file));
    }

    // Videos, one after another, sharing what's left of the progress bar.
    const heavy = (audio ? 1 : 0) + videos.length;
    let done = audio ? 1 : 0;
    for (const { m, i } of videos) {
      const base = share + (done / heavy) * (1 - share);
      const span = (1 - share) / heavy;
      const file = `video-${i}.mp4`;
      const source = directVideoSource(String(m.video_url));
      let saved = false;
      for (const url of source === m.video_url ? [source] : [source, String(m.video_url)]) {
        try {
          const task = FileSystem.createDownloadResumable(url, folder + file, {}, (p) => {
            if (p.totalBytesExpectedToWrite > 0) {
              setProgress(itemId, base + (p.totalBytesWritten / p.totalBytesExpectedToWrite) * span);
            }
          });
          const result = await task.downloadAsync();
          if (result && result.status >= 200 && result.status < 300) {
            saved = true;
            break;
          }
        } catch {
          // Try the next address.
        }
        await FileSystem.deleteAsync(folder + file, { idempotent: true }).catch(() => undefined);
      }
      done++;
      if (!saved) {
        // A video link that expired (Facebook's do after a few days) stays a
        // link; the rest of the post is still saved.
        continue;
      }
      // Reddit: fetch the sound that goes with the picture.
      let audioFile: string | null = null;
      for (const url of redditAudioCandidates(String(m.video_url))) {
        const name = `video-${i}-audio.mp4`;
        try {
          const result = await FileSystem.downloadAsync(url, folder + name);
          if (result.status >= 200 && result.status < 300) {
            audioFile = name;
            break;
          }
        } catch {
          // Try the next name.
        }
        await FileSystem.deleteAsync(folder + name, { idempotent: true }).catch(() => undefined);
      }
      const poster = typeof m.url === "string" && m.url.startsWith(LOCAL) ? m.url.slice(LOCAL.length) : null;
      const page = `video-${i}.html`;
      await FileSystem.writeAsStringAsync(folder + page, videoPlayerHtml(file, poster, audioFile));
      m.video_url = LOCAL + file;
      m.hls_url = null;
      m.local_player = LOCAL + page;
    }

    item.media = media as ItemWithAnalysis["media"];
    await FileSystem.writeAsStringAsync(folder + "item.json", JSON.stringify(item));

    const names = await FileSystem.readDirectoryAsync(folder);
    const sizes = await Promise.all(names.map((n) => fileSize(folder + n)));
    const entry: DownloadEntry = {
      itemId,
      title: item.title,
      platform: item.platform,
      channelName: item.channel_name,
      thumbFile: thumbFile ?? (images.find((img) => img.file.startsWith("media-") || img.file.startsWith("embed-"))?.file ?? null),
      savedAt: new Date().toISOString(),
      bytes: sizes.reduce((a, b) => a + b, 0),
      hasAudio: !!audio,
    };
    // Only point at a thumbnail that actually saved.
    if (entry.thumbFile && !names.includes(entry.thumbFile)) entry.thumbFile = null;

    const entries = { ...useDownloadsStore.getState().entries, [itemId]: entry };
    useDownloadsStore.setState({ entries });
    await writeIndex(entries);
    return entry;
  } catch (e) {
    await FileSystem.deleteAsync(folder, { idempotent: true }).catch(() => undefined);
    throw e instanceof Error ? e : new Error(i18n.t("downloads.failed"));
  } finally {
    setProgress(itemId, null);
  }
}

function resolveLocal(itemId: string, value: unknown): unknown {
  return typeof value === "string" && value.startsWith(LOCAL) ? localFileUri(itemId, value.slice(LOCAL.length)) : value;
}

/** The saved copy of an item, with links pointing at the files on the phone. */
export async function readDownloadedItem(itemId: string): Promise<ItemWithAnalysis | null> {
  if (!downloadsSupported) return null;
  await loadDownloads();
  if (!useDownloadsStore.getState().entries[itemId]) return null;
  try {
    const item = JSON.parse(await FileSystem.readAsStringAsync(localFileUri(itemId, "item.json"))) as ItemWithAnalysis;
    item.thumbnail_url = resolveLocal(itemId, item.thumbnail_url) as string | null;
    item.media = ((item.media ?? []) as MediaEntry[]).map((m) => ({
      ...m,
      url: resolveLocal(itemId, m.url),
      image: resolveLocal(itemId, m.image),
      audio_url: resolveLocal(itemId, m.audio_url),
      video_url: resolveLocal(itemId, m.video_url),
      local_player: resolveLocal(itemId, m.local_player),
    })) as ItemWithAnalysis["media"];
    return item;
  } catch {
    return null;
  }
}

export async function deleteDownload(itemId: string): Promise<void> {
  if (!downloadsSupported) return;
  await loadDownloads();
  await FileSystem.deleteAsync(itemFolder(itemId), { idempotent: true });
  const entries = { ...useDownloadsStore.getState().entries };
  delete entries[itemId];
  useDownloadsStore.setState({ entries });
  await writeIndex(entries);
}

export async function deleteAllDownloads(): Promise<void> {
  if (!downloadsSupported || !ROOT) return;
  await FileSystem.deleteAsync(ROOT, { idempotent: true });
  useDownloadsStore.setState({ entries: {} });
  await writeIndex({});
}

export function formatBytes(bytes: number): string {
  if (bytes >= 1024 * 1024 * 1024) return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GB`;
  if (bytes >= 1024 * 1024) return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  if (bytes >= 1024) return `${Math.round(bytes / 1024)} KB`;
  return `${bytes} B`;
}
