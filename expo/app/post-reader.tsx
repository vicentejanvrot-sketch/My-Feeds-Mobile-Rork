// In-app reader for X, Reddit, Instagram, LinkedIn and GitHub posts — the mobile twin of the web
// PostReaderModal, so reading works the same everywhere.
import { useEffect, useRef, useState } from "react";
import { ActivityIndicator, AppState, Modal, Platform as RNPlatform, Pressable, ScrollView, Share, StyleSheet, Text, View, useWindowDimensions } from "react-native";
import type { WebViewMessageEvent } from "react-native-webview";
import { WebView } from "react-native-webview";
import Svg, { Path } from "react-native-svg";
import { useLocalSearchParams, router } from "expo-router";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Image } from "expo-image";
import * as Haptics from "expo-haptics";
import { useQuery } from "@tanstack/react-query";
import { withFreshMedia } from "@/lib/expired-media";
import {
  X,
  ExternalLink,
  Heart,
  Repeat2,
  MessageCircle,
  MessageSquare,
  BadgeCheck,
  Bookmark,
  Share as ShareIcon,
  ArrowBigUp,
  ArrowBigDown,
  Check,
  Send,
  ThumbsUp,
  Play,
  Maximize2,
  Star,
  GitFork,
  ListPlus,
} from "lucide-react-native";
import { Colors } from "@/constants/colors";
import { supabase } from "@/lib/supabase";
import { useUpdateItemStatus } from "@/lib/hooks";
import { useToast } from "@/components/Toast";
import { openExternalLink } from "@/lib/open-link";
import { timeAgo } from "@/lib/format";
import { PlatformBadge } from "@/components/PlatformBadge";
import { PLATFORM_META, platformOf, formatCount, isNewPostsCard } from "@/lib/platforms";
import {
  POSITION_SAVE_INTERVAL_MS,
  minResumeSeconds,
  isNearEnd,
  saveResumePosition,
  loadResumePosition,
  clearResumePosition,
} from "@/lib/video-progress";
import type { ItemStatus, ItemWithAnalysis } from "@/lib/database";
import { DownloadButton } from "@/components/DownloadButton";
import { podcastPlayerHtml, readDownloadedItem, useDownloadsStore } from "@/lib/downloads";
import { AppleMusicError, addReleaseToAppleMusic, appleMusicSupported } from "@/lib/appleMusic";
import YoutubeIframe from "react-native-youtube-iframe";
import { useYouTubeConnection } from "@/lib/useYouTubeConnection";

// The action bar copies each platform's own row under a post. In My Feeds:
// Like / Upvote = Saved, Bookmark / Save = Read Later, the check = Read.
// Reply and Repost open the post on X, since those happen on the platform.
const X_PINK = "#F91880";
const X_BLUE = "#1D9BF0";
const REDDIT_ORANGE = "#FF4500";
const IG_RED = "#FF3040";
const LINKEDIN_BLUE = "#378FE9";
const TIKTOK_RED = "#FE2C55";
const TIKTOK_YELLOW = "#FACE15";
const FACEBOOK_BLUE = "#0866FF";
const APPLE_MUSIC_RED = "#FA243C";
const APPLE_PODCASTS_PURPLE = "#B35CF2";
const APPLE_BOOKS_ORANGE = "#FF9500";
const YOUTUBE_MUSIC_RED = "#FF0033";
const GITHUB_STAR = "#E3B341";

type PostMetrics = {
  likes?: number;
  reposts?: number;
  replies?: number;
  views?: number;
  plays?: number;
  bookmarks?: number;
  quotes?: number;
  score?: number;
  comments?: number;
  stars?: number;
  forks?: number;
};

// An image, or a quoted post / X article (type "quote" / "article").
type PostEmbed = {
  type: string;
  url: string;
  author_name?: string;
  author_handle?: string;
  author_avatar?: string | null;
  verified?: boolean;
  created_at?: string | null;
  text?: string;
  image?: string | null;
  title?: string | null;
  preview?: string | null;
  // Playable video: MP4, and an HLS stream (plays with sound on iOS).
  video_url?: string | null;
  hls_url?: string | null;
  // Downloaded copy only: the page on the phone that plays the saved video.
  local_player?: string | null;
  // Apple Podcasts episode: the audio file and its length in seconds.
  audio_url?: string | null;
  duration?: number | null;
  // Apple Books audiobook: Apple's short sample.
  preview_url?: string | null;
  // YouTube Music: the release's track video ids, or a music video's id.
  video_ids?: string[] | null;
  youtube_id?: string | null;
  track_count?: number | null;
  // Apple Music release: Apple's embed player link, and single / ep / album.
  embed_url?: string | null;
  kind?: string | null;
  label?: string | null;
  // Spotify release: the Apple Music link it was found from, so the reader can
  // look for the Spotify match again while Spotify's player isn't known yet.
  source_url?: string | null;
};

function escapeAttr(value: string): string {
  return value.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
}

// Instagram videos are stored behind our media-proxy, but the CDN plays them
// fine straight from Instagram as long as no Referer is sent. Going direct
// avoids the extra hop on every chunk, which made playback pause after the
// first second. The proxied link stays as a fallback.
function directVideoUrl(url: string | null | undefined): string | null {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    if (!parsed.pathname.endsWith("/functions/v1/media-proxy")) return null;
    const inner = new URL(parsed.searchParams.get("u") ?? "");
    const host = inner.hostname.toLowerCase();
    return host.endsWith(".cdninstagram.com") || host.endsWith(".fbcdn.net") ? inner.toString() : null;
  } catch {
    return null;
  }
}

// Reports the video's position to the app once a second, plus pause, end and
// "ready" (length known), and lets the app seek with window.__seekTo(seconds).
const VIDEO_PROGRESS_JS =
  "(function(){" +
  "var v=document.querySelector('video');if(!v)return;" +
  "function send(type){try{window.ReactNativeWebView.postMessage(JSON.stringify({type:type,t:v.currentTime||0,d:isFinite(v.duration)?v.duration:0}));}catch(e){}}" +
  "var last=0;" +
  "v.addEventListener('loadedmetadata',function(){send('ready');});" +
  "v.addEventListener('timeupdate',function(){var now=Date.now();if(now-last>=1000){last=now;send('time');}});" +
  "v.addEventListener('pause',function(){if(!v.ended)send('pause');});" +
  "v.addEventListener('ended',function(){send('ended');});" +
  // Only jump if the user hasn't already moved past the first second.
  "window.__seekTo=function(s){try{if(v.currentTime<1)v.currentTime=s;}catch(e){}};" +
  "if(v.readyState>=1)send('ready');" +
  "})();true;";

// Plays a post's video in place, like on X and Reddit. iOS plays the HLS
// stream; Android gets the MP4. No Referer is sent: X's video server
// refuses requests that carry another site's address.
// progressId (the item's video_id, e.g. "x:123") turns on resume, the same as
// YouTube videos: saved every 5 s while playing, on pause, on close and when the
// app goes to the background, on the phone and in the shared video_progress
// table, so the web and iOS apps pick up from the same spot.
// fill: take the whole parent (full screen viewer) instead of a 16:9 box.
// autoPlay: start playing on its own (full screen, opened with a tap).
function PostVideo({ media, progressId, fill, autoPlay }: { media: PostEmbed; progressId?: string | null; fill?: boolean; autoPlay?: boolean }) {
  const webRef = useRef<WebView>(null);
  const latest = useRef({ t: 0, d: 0 });
  const lastSave = useRef(0);
  const resumed = useRef(false);

  // Closing the post or leaving the app: save where the video was.
  useEffect(() => {
    if (!progressId) return;
    resumed.current = false;
    const sub = AppState.addEventListener("change", (state) => {
      if (state !== "active") void saveResumePosition(progressId, latest.current.t, latest.current.d);
    });
    return () => {
      sub.remove();
      void saveResumePosition(progressId, latest.current.t, latest.current.d);
    };
  }, [progressId]);

  const onMessage = (event: WebViewMessageEvent) => {
    if (!progressId) return;
    let msg: { type?: string; t?: number; d?: number };
    try {
      msg = JSON.parse(event.nativeEvent.data);
    } catch {
      return;
    }
    const t = Number(msg.t) || 0;
    const d = Number(msg.d) || 0;
    latest.current = { t, d };
    if (msg.type === "ready") {
      if (resumed.current) return;
      resumed.current = true;
      void loadResumePosition(progressId).then((saved) => {
        if (!saved || saved.duration <= 0) return;
        if (isNearEnd(saved.currentTime, saved.duration)) {
          void clearResumePosition(progressId);
        } else if (saved.currentTime >= minResumeSeconds(saved.duration)) {
          webRef.current?.injectJavaScript("window.__seekTo&&window.__seekTo(" + saved.currentTime + ");true;");
        }
      });
    } else if (msg.type === "ended") {
      latest.current = { t: 0, d };
      void clearResumePosition(progressId);
    } else if (msg.type === "pause") {
      lastSave.current = Date.now();
      void saveResumePosition(progressId, t, d);
    } else if (msg.type === "time" && Date.now() - lastSave.current >= POSITION_SAVE_INTERVAL_MS) {
      lastSave.current = Date.now();
      void saveResumePosition(progressId, t, d);
    }
  };

  // A downloaded video plays from the phone, through the page saved next to it.
  if (media.local_player) {
    const folder = media.local_player.slice(0, media.local_player.lastIndexOf("/") + 1);
    return (
      <View style={fill ? styles.videoFill : styles.video}>
        <WebView
          ref={webRef}
          source={{ uri: media.local_player }}
          originWhitelist={["*"]}
          injectedJavaScript={progressId ? VIDEO_PROGRESS_JS : undefined}
          onMessage={progressId ? onMessage : undefined}
          allowsInlineMediaPlayback
          mediaPlaybackRequiresUserAction={!autoPlay}
          allowsFullscreenVideo
          allowFileAccess
          allowFileAccessFromFileURLs
          allowingReadAccessToURL={folder}
          scrollEnabled={false}
          style={styles.videoWeb}
        />
      </View>
    );
  }

  const main =
    (RNPlatform.OS === "ios" ? media.hls_url || media.video_url : media.video_url || media.hls_url) || "";
  if (!main) return null;
  const direct = directVideoUrl(media.video_url);
  const sources = (direct ? [direct, main] : [main])
    .map((src) => `<source src="${escapeAttr(src)}">`)
    .join("");
  const poster = media.url || media.image || "";
  const html = `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><meta name="referrer" content="no-referrer">
<style>html,body{margin:0;padding:0;background:#000;height:100%}video{width:100%;height:100%;object-fit:contain;background:#000}</style></head>
<body><video${poster ? ` poster="${escapeAttr(poster)}"` : ""} controls playsinline webkit-playsinline preload="auto"${autoPlay ? " autoplay" : ""}>${sources}</video></body></html>`;
  return (
    <View style={fill ? styles.videoFill : styles.video}>
      <WebView
        ref={webRef}
        source={{ html }}
        originWhitelist={["*"]}
        injectedJavaScript={progressId ? VIDEO_PROGRESS_JS : undefined}
        onMessage={progressId ? onMessage : undefined}
        allowsInlineMediaPlayback
        mediaPlaybackRequiresUserAction={!autoPlay}
        allowsFullscreenVideo
        scrollEnabled={false}
        style={styles.videoWeb}
      />
    </View>
  );
}

// TikTok videos play in TikTok's own embed player: TikTok's CDN links expire
// and refuse to play outside TikTok, while the player always works.
function TikTokPlayer({ videoId }: { videoId: string }) {
  const { width } = useWindowDimensions();
  const playerWidth = Math.min(width - 32, 380);
  return (
    <View style={styles.tiktokWrap}>
      <WebView
        source={{ uri: `https://www.tiktok.com/player/v1/${encodeURIComponent(videoId)}?music_info=1&description=0&rel=0&native_context_menu=0` }}
        style={{ width: playerWidth, height: (playerWidth * 16) / 9, backgroundColor: "#000000" }}
        allowsInlineMediaPlayback
        allowsFullscreenVideo
        mediaPlaybackRequiresUserAction={false}
        javaScriptEnabled
        scrollEnabled={false}
        accessibilityLabel="TikTok video"
      />
    </View>
  );
}

// A Facebook video. Facebook won't embed some videos (licensed music and the
// like), so the saved video file plays first. Once that file has expired
// (Facebook's links last a few days), Facebook's own player instead.
function FacebookVideo({ media, postUrl, progressId }: { media: PostEmbed; postUrl: string | null | undefined; progressId?: string | null }) {
  const embed = facebookEmbed(postUrl);
  const src = media.video_url || media.hls_url || "";
  const [mode, setMode] = useState<"checking" | "file" | "embed">(src ? "checking" : "embed");
  useEffect(() => {
    if (!src) {
      setMode("embed");
      return;
    }
    let cancelled = false;
    setMode("checking");
    // Asks for the file's first two bytes: any answer but a 2xx means it's gone.
    fetch(src, { headers: { Range: "bytes=0-1" } })
      .then((r) => { if (!cancelled) setMode(r.ok ? "file" : "embed"); })
      .catch(() => { if (!cancelled) setMode("embed"); });
    return () => { cancelled = true; };
  }, [src]);
  if (mode === "file" || !embed) return <ExpandableMedia media={media} progressId={progressId} />;
  if (mode === "embed") return <FacebookPlayer {...embed} />;
  return (
    <View style={[styles.video, { alignItems: "center", justifyContent: "center" }]}>
      <ActivityIndicator color="#ffffff" />
    </View>
  );
}

// Facebook's embed player, used when the saved video file has expired. Reels
// are portrait, other videos landscape.
function facebookEmbed(postUrl: string | null | undefined): { uri: string; portrait: boolean } | null {
  if (!postUrl || !/facebook\.com\//i.test(postUrl)) return null;
  const reel = postUrl.match(/facebook\.com\/reel\/(\d+)/i);
  const href = reel ? `https://www.facebook.com/watch/?v=${reel[1]}` : postUrl;
  return {
    uri: `https://www.facebook.com/plugins/video.php?href=${encodeURIComponent(href)}&show_text=false&autoplay=false&allowfullscreen=true`,
    portrait: !!reel,
  };
}

function FacebookPlayer({ uri, portrait }: { uri: string; portrait: boolean }) {
  const { width } = useWindowDimensions();
  const playerWidth = portrait ? Math.min(width - 32, 380) : width - 32;
  const playerHeight = portrait ? (playerWidth * 16) / 9 : (playerWidth * 9) / 16;
  return (
    <View style={styles.tiktokWrap}>
      <WebView
        source={{ uri }}
        style={{ width: playerWidth, height: playerHeight, backgroundColor: "#000000" }}
        allowsInlineMediaPlayback
        allowsFullscreenVideo
        mediaPlaybackRequiresUserAction={false}
        javaScriptEnabled
        scrollEnabled={false}
        accessibilityLabel="Facebook video"
      />
    </View>
  );
}

const SPOTIFY_GREEN = "#1DB954";
const SPOTIFY_PATH =
  "M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z";

function SpotifyLogo({ size = 16 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24">
      <Path d={SPOTIFY_PATH} fill={SPOTIFY_GREEN} />
    </Svg>
  );
}

// Spotify's player without protected (DRM) playback: with it, the player
// starts DRM as soon as it loads, which on some devices switches the display
// mode and blanks the screen for a few seconds when the player opens and
// closes. Without it Spotify plays its 30-second previews, which need no DRM.
const SPOTIFY_NO_DRM_JS =
  "try{Object.defineProperty(navigator,'requestMediaKeySystemAccess',{value:undefined,configurable:true});" +
  "window.MediaKeys=undefined;window.WebKitMediaKeys=undefined;}catch(e){}true;";

// The same release on Spotify, found by the spotify-link function (Songlink).
// "Play on Spotify" opens Spotify's own embed player here (on phones it usually
// plays 30-second previews), "Open in Spotify" goes to the Spotify app.
// Nothing shows when Spotify doesn't have the release.
function SpotifySection({ sourceUrl }: { sourceUrl: string }) {
  const [playing, setPlaying] = useState(false);
  const { data } = useQuery({
    queryKey: ["spotify-link", sourceUrl],
    staleTime: 24 * 3600 * 1000,
    queryFn: async () => {
      const { data, error } = await supabase.functions.invoke("spotify-link", { body: { url: sourceUrl } });
      if (error) return null;
      return (data ?? null) as { spotifyUrl?: string | null; embedUrl?: string | null; kind?: string | null } | null;
    },
  });
  if (!data?.spotifyUrl) return null;
  const spotifyUrl = data.spotifyUrl;
  const tall = data.kind === "album" || data.kind === "playlist";
  return (
    <View style={{ gap: 10 }}>
      <View style={{ flexDirection: "row", gap: 10 }}>
        {data.embedUrl ? (
          <Pressable
            onPress={() => setPlaying((v) => !v)}
            style={({ pressed }) => [styles.openBtn, { flex: 1 }, pressed && { opacity: 0.7 }]}
            accessibilityRole="button"
          >
            <SpotifyLogo />
            <Text style={styles.openText}>{playing ? "Hide player" : "Play on Spotify"}</Text>
          </Pressable>
        ) : null}
        <Pressable
          onPress={() => void openExternalLink(spotifyUrl)}
          style={({ pressed }) => [styles.openBtn, { flex: 1 }, pressed && { opacity: 0.7 }]}
          accessibilityRole="link"
        >
          <ExternalLink size={16} color={Colors.textPrimary} />
          <Text style={styles.openText}>Open in Spotify</Text>
        </Pressable>
      </View>
      {playing && data.embedUrl ? (
        <View style={[styles.appleEmbed, { height: tall ? 352 : 152 }]}>
          <WebView
            source={{ uri: data.embedUrl }}
            style={{ flex: 1, backgroundColor: "transparent" }}
            allowsInlineMediaPlayback
            mediaPlaybackRequiresUserAction={false}
            javaScriptEnabled
            scrollEnabled={tall}
            injectedJavaScriptBeforeContentLoaded={SPOTIFY_NO_DRM_JS}
            accessibilityLabel="Spotify player"
          />
        </View>
      ) : null}
    </View>
  );
}

// A Spotify release saved before Songlink could match it (new releases often
// take a few days). Asks spotify-link again from the Apple link and shows
// Spotify's player as soon as there's a match; until then, the artwork and a
// note, with "Open in Spotify" below searching Spotify for it.
function SpotifyPendingRelease({ sourceUrl, title, artistId, artistName }: {
  sourceUrl: string;
  title: string;
  artistId: string | null;
  artistName: string | null;
}) {
  const { data, isLoading } = useQuery({
    queryKey: ["spotify-link", sourceUrl],
    staleTime: 3600 * 1000,
    queryFn: async () => {
      const { data, error } = await supabase.functions.invoke("spotify-link", { body: { url: sourceUrl } });
      if (error) return null;
      return (data ?? null) as { spotifyUrl?: string | null; embedUrl?: string | null; kind?: string | null } | null;
    },
  });
  if (data?.embedUrl) {
    const embedUrl = data.embedUrl;
    const spotifyUrl = data.spotifyUrl;
    const short = data.kind === "track";
    return (
      <View style={{ gap: 12 }}>
        <View style={[styles.appleEmbed, { height: short ? 152 : 352 }]}>
          <WebView
            source={{ uri: embedUrl }}
            style={{ flex: 1, backgroundColor: "transparent" }}
            allowsInlineMediaPlayback
            mediaPlaybackRequiresUserAction={false}
            javaScriptEnabled
            scrollEnabled={!short}
            injectedJavaScriptBeforeContentLoaded={SPOTIFY_NO_DRM_JS}
            accessibilityLabel="Spotify player"
          />
        </View>
        {spotifyUrl ? (
          <Pressable
            onPress={() => void openExternalLink(spotifyUrl)}
            style={({ pressed }) => [styles.openBtn, pressed && { opacity: 0.7 }]}
            accessibilityRole="link"
          >
            <SpotifyLogo />
            <Text style={styles.openText}>Open in Spotify</Text>
          </Pressable>
        ) : null}
      </View>
    );
  }
  if (isLoading) return <Text style={[styles.muted, { textAlign: "center" }]}>Looking for it on Spotify…</Text>;
  if (!artistId) return null;
  // Until Spotify links the release, the artist's own Spotify player: their
  // popular songs, as previews, right here.
  return (
    <View style={{ gap: 10 }}>
      <View style={[styles.appleEmbed, { height: 352 }]}>
        <WebView
          source={{ uri: `https://open.spotify.com/embed/artist/${artistId}` }}
          style={{ flex: 1, backgroundColor: "transparent" }}
          allowsInlineMediaPlayback
          mediaPlaybackRequiresUserAction={false}
          javaScriptEnabled
          injectedJavaScriptBeforeContentLoaded={SPOTIFY_NO_DRM_JS}
          accessibilityLabel={`${artistName ?? "Artist"} on Spotify`}
        />
      </View>
      <Text style={[styles.muted, { textAlign: "center" }]}>
        {`Spotify hasn't linked "${title}" yet (new releases can take a few days), so this plays ${artistName ?? "the artist"}'s popular songs. Open in Spotify searches for the new release.`}
      </Text>
    </View>
  );
}

// Podcasts: Spotify's search for the episode (Songlink doesn't cover podcasts).
function spotifyEpisodeSearchUrl(title: string, show: string | null | undefined): string {
  const q = [title, show].filter(Boolean).join(" ").slice(0, 120);
  return `https://open.spotify.com/search/${encodeURIComponent(q)}/episodes`;
}

// Apple Music's own player: previews for everyone, full songs for listeners
// signed in to Apple Music. A single is a short strip, an album shows its tracks.
function AppleMusicPlayer({ embedUrl, single }: { embedUrl: string; single: boolean }) {
  return (
    <View style={[styles.appleEmbed, { height: single ? 175 : 450 }]}>
      <WebView
        source={{ uri: embedUrl }}
        style={{ flex: 1, backgroundColor: "transparent" }}
        allowsInlineMediaPlayback
        mediaPlaybackRequiresUserAction={false}
        javaScriptEnabled
        scrollEnabled={!single}
        accessibilityLabel="Apple Music player"
      />
    </View>
  );
}

// "Add to Apple Music": puts the release's songs in the user's "My Feeds"
// playlist in Apple Music, where they can listen and download them for offline.
function AddToAppleMusic({ albumId, single }: { albumId: string; single: boolean }) {
  const showToast = useToast();
  const [state, setState] = useState<"idle" | "adding" | "added">("idle");
  if (!appleMusicSupported) return null;

  const add = async () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setState("adding");
    try {
      const { added } = await addReleaseToAppleMusic(albumId);
      setState("added");
      showToast(`Added ${added} ${added === 1 ? "song" : "songs"} to "My Feeds" in Apple Music`, "success");
    } catch (e) {
      setState("idle");
      if (e instanceof AppleMusicError && e.code === "cancelled") return;
      showToast(e instanceof Error ? e.message : "Couldn't add to Apple Music", "error");
    }
  };

  return (
    <View style={{ gap: 6 }}>
      <Pressable
        onPress={() => void add()}
        disabled={state !== "idle"}
        style={({ pressed }) => [styles.openBtn, pressed && { opacity: 0.7 }, state === "adding" && { opacity: 0.6 }]}
        accessibilityRole="button"
      >
        {state === "adding" ? (
          <ActivityIndicator size="small" color={APPLE_MUSIC_RED} />
        ) : state === "added" ? (
          <Check size={16} color={APPLE_MUSIC_RED} />
        ) : (
          <ListPlus size={16} color={APPLE_MUSIC_RED} />
        )}
        <Text style={styles.openText}>
          {state === "added" ? "Added to Apple Music" : single ? "Add song to Apple Music" : "Add album to Apple Music"}
        </Text>
      </Pressable>
      <Text style={[styles.muted, { textAlign: "center", fontSize: 12 }]}>
        Goes into your "My Feeds" playlist. Needs an Apple Music subscription. Turn on Automatic Downloads in Apple Music to
        keep the songs offline.
      </Text>
    </View>
  );
}

// YouTube Music songs, albums (all tracks in a row) and music videos, in
// YouTube's own player.
function YouTubeMusicPlayer({ videoIds }: { videoIds: string[] }) {
  const { width } = useWindowDimensions();
  const playerWidth = Math.min(width, 720) - 32;
  return (
    <View style={styles.video}>
      <YoutubeIframe
        width={playerWidth}
        height={(playerWidth * 9) / 16}
        videoId={videoIds[0]}
        playList={videoIds.length > 1 ? videoIds : undefined}
        initialPlayerParams={{ modestbranding: true, rel: false }}
      />
    </View>
  );
}

// "Add to YouTube Music": puts the songs in the user's "My Feeds" playlist,
// through the YouTube account connected in Settings. YouTube Music shows that
// playlist, where the songs can be played or downloaded (with Premium).
function AddToYouTubeMusic({ videoIds, kind }: { videoIds: string[]; kind: string }) {
  const showToast = useToast();
  const youtube = useYouTubeConnection();
  const [state, setState] = useState<"idle" | "adding" | "added">("idle");
  const connected = youtube.status === "connected";
  const what = kind === "video" ? "video" : kind === "single" ? "song" : kind === "ep" ? "EP" : "album";

  const add = async () => {
    void Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (!connected) {
      await youtube.connect();
      return;
    }
    setState("adding");
    try {
      const { added } = await youtube.addToMusicPlaylist(videoIds);
      setState("added");
      showToast(
        added > 0
          ? `Added ${added} ${added === 1 ? (kind === "video" ? "video" : "song") : kind === "video" ? "videos" : "songs"} to "My Feeds" in YouTube Music`
          : `Already in your "My Feeds" playlist`,
        "success",
      );
    } catch (e) {
      setState("idle");
      showToast(e instanceof Error ? e.message : "Couldn't add to YouTube Music", "error");
    }
  };

  return (
    <View style={{ gap: 6 }}>
      <Pressable
        onPress={() => void add()}
        disabled={state !== "idle" || youtube.connecting}
        style={({ pressed }) => [styles.openBtn, pressed && { opacity: 0.7 }, state === "adding" && { opacity: 0.6 }]}
        accessibilityRole="button"
      >
        {state === "adding" || youtube.connecting ? (
          <ActivityIndicator size="small" color={YOUTUBE_MUSIC_RED} />
        ) : state === "added" ? (
          <Check size={16} color={YOUTUBE_MUSIC_RED} />
        ) : (
          <ListPlus size={16} color={YOUTUBE_MUSIC_RED} />
        )}
        <Text style={styles.openText}>
          {state === "added" ? "Added to YouTube Music" : connected ? `Add ${what} to YouTube Music` : "Connect YouTube to add it"}
        </Text>
      </Pressable>
      <Text style={[styles.muted, { textAlign: "center", fontSize: 12 }]}>
        Goes into your "My Feeds" playlist. With YouTube Music Premium you can download it for offline listening.
      </Text>
    </View>
  );
}

// Apple Books audiobook: the cover and Apple's short sample. The whole book is
// bought and played in Apple Books, so this doesn't count toward watch time.
function AudiobookCard({ media }: { media: PostEmbed }) {
  const html = media.preview_url
    ? `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><meta name="referrer" content="no-referrer">
<style>html,body{margin:0;padding:0;background:transparent}audio{width:100%;display:block}</style></head>
<body><audio controls preload="none" src="${escapeAttr(media.preview_url)}"></audio></body></html>`
    : null;
  return (
    <View style={styles.podcastCard}>
      <View style={styles.podcastTop}>
        {media.url ? <Image source={{ uri: media.url }} style={styles.audiobookCover} contentFit="cover" /> : null}
        <View style={{ flex: 1, gap: 4 }}>
          {media.label ? <Text style={styles.audiobookLabel}>{media.label.toUpperCase()}</Text> : null}
          <Text style={styles.muted}>
            {html ? "Sample from Apple Books. The full book plays in Apple Books." : "No sample for this one. The full book plays in Apple Books."}
          </Text>
        </View>
      </View>
      {html ? (
        <View style={styles.podcastAudio}>
          <WebView
            source={{ html }}
            originWhitelist={["*"]}
            allowsInlineMediaPlayback
            mediaPlaybackRequiresUserAction
            scrollEnabled={false}
            style={{ backgroundColor: "transparent" }}
            accessibilityLabel="Audiobook sample"
          />
        </View>
      ) : null}
    </View>
  );
}

function formatClock(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = String(s % 60).padStart(2, "0");
  return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${sec}` : `${m}:${sec}`;
}

const PODCAST_SPEEDS = [1, 1.25, 1.5, 2];

// Same bridge as VIDEO_PROGRESS_JS, for the <audio> element, plus skip and speed.
const AUDIO_PROGRESS_JS =
  "(function(){" +
  "var v=document.querySelector('audio');if(!v)return;" +
  "function send(type){try{window.ReactNativeWebView.postMessage(JSON.stringify({type:type,t:v.currentTime||0,d:isFinite(v.duration)?v.duration:0}));}catch(e){}}" +
  "var last=0;" +
  "v.addEventListener('loadedmetadata',function(){send('ready');});" +
  "v.addEventListener('timeupdate',function(){var now=Date.now();if(now-last>=1000){last=now;send('time');}});" +
  "v.addEventListener('pause',function(){if(!v.ended)send('pause');});" +
  "v.addEventListener('ended',function(){send('ended');});" +
  "window.__seekTo=function(s){try{if(v.currentTime<1)v.currentTime=s;}catch(e){}};" +
  "window.__skip=function(d){try{v.currentTime=Math.max(0,v.currentTime+d);}catch(e){}};" +
  "window.__speed=function(r){try{v.playbackRate=r;}catch(e){}};" +
  "if(v.readyState>=1)send('ready');" +
  "})();true;";

// Full podcast episodes play right here. The position is saved like a video's
// (on the phone and in video_progress), so it resumes on any device, and
// finishing an episode marks it as watched so it counts in watch time.
function PodcastPlayer({ media, progressId, onFinished }: { media: PostEmbed; progressId: string; onFinished: () => void }) {
  const webRef = useRef<WebView>(null);
  const latest = useRef({ t: 0, d: 0 });
  const lastSave = useRef(0);
  const resumed = useRef(false);
  const [speed, setSpeed] = useState(1);
  const [resumeAt, setResumeAt] = useState<number | null>(null);

  useEffect(() => {
    resumed.current = false;
    const sub = AppState.addEventListener("change", (state) => {
      if (state !== "active") void saveResumePosition(progressId, latest.current.t, latest.current.d);
    });
    return () => {
      sub.remove();
      void saveResumePosition(progressId, latest.current.t, latest.current.d);
    };
  }, [progressId]);

  const onMessage = (event: WebViewMessageEvent) => {
    let msg: { type?: string; t?: number; d?: number };
    try {
      msg = JSON.parse(event.nativeEvent.data);
    } catch {
      return;
    }
    const t = Number(msg.t) || 0;
    const d = Number(msg.d) || media.duration || 0;
    latest.current = { t, d };
    if (msg.type === "ready") {
      if (resumed.current) return;
      resumed.current = true;
      void loadResumePosition(progressId).then((saved) => {
        if (!saved || saved.duration <= 0) return;
        if (isNearEnd(saved.currentTime, saved.duration)) {
          void clearResumePosition(progressId);
        } else if (saved.currentTime >= minResumeSeconds(saved.duration)) {
          setResumeAt(saved.currentTime);
          webRef.current?.injectJavaScript("window.__seekTo&&window.__seekTo(" + saved.currentTime + ");true;");
        }
      });
    } else if (msg.type === "ended") {
      latest.current = { t: 0, d };
      void clearResumePosition(progressId);
      onFinished();
    } else if (msg.type === "pause") {
      lastSave.current = Date.now();
      void saveResumePosition(progressId, t, d);
    } else if (msg.type === "time" && Date.now() - lastSave.current >= POSITION_SAVE_INTERVAL_MS) {
      lastSave.current = Date.now();
      void saveResumePosition(progressId, t, d);
    }
  };

  if (!media.audio_url) return null;
  // A downloaded episode plays from the phone: the saved player.html sits next
  // to the audio file, and the web view is allowed to read that folder only.
  const localFolder = media.audio_url.startsWith("file:")
    ? media.audio_url.slice(0, media.audio_url.lastIndexOf("/") + 1)
    : null;
  const source = localFolder ? { uri: `${localFolder}player.html` } : { html: podcastPlayerHtml(media.audio_url) };
  const skip = (delta: number) => webRef.current?.injectJavaScript("window.__skip&&window.__skip(" + delta + ");true;");
  const changeSpeed = () => {
    const next = PODCAST_SPEEDS[(PODCAST_SPEEDS.indexOf(speed) + 1) % PODCAST_SPEEDS.length];
    setSpeed(next);
    webRef.current?.injectJavaScript("window.__speed&&window.__speed(" + next + ");true;");
  };

  return (
    <View style={styles.podcastCard}>
      <View style={styles.podcastTop}>
        {media.url ? <Image source={{ uri: media.url }} style={styles.podcastArt} contentFit="cover" /> : null}
        <View style={{ flex: 1, gap: 2 }}>
          <Text style={styles.muted}>{media.duration ? `${formatClock(media.duration)} long` : "Full episode"}{localFolder ? " · Downloaded" : ""}</Text>
          {resumeAt != null ? <Text style={styles.podcastResume}>Resumes at {formatClock(resumeAt)}</Text> : null}
        </View>
      </View>
      <View style={styles.podcastAudio}>
        <WebView
          ref={webRef}
          source={source}
          originWhitelist={["*"]}
          allowFileAccess={!!localFolder}
          allowFileAccessFromFileURLs={!!localFolder}
          allowingReadAccessToURL={localFolder ?? undefined}
          injectedJavaScript={AUDIO_PROGRESS_JS}
          onMessage={onMessage}
          allowsInlineMediaPlayback
          mediaPlaybackRequiresUserAction
          scrollEnabled={false}
          style={{ backgroundColor: "transparent" }}
          accessibilityLabel="Podcast player"
        />
      </View>
      <View style={styles.podcastControls}>
        <Pressable onPress={() => skip(-15)} style={styles.podcastBtn} accessibilityRole="button" accessibilityLabel="Back 15 seconds">
          <Text style={styles.podcastBtnText}>Back 15s</Text>
        </Pressable>
        <Pressable onPress={() => skip(30)} style={styles.podcastBtn} accessibilityRole="button" accessibilityLabel="Forward 30 seconds">
          <Text style={styles.podcastBtnText}>Forward 30s</Text>
        </Pressable>
        <Pressable onPress={changeSpeed} style={styles.podcastBtn} accessibilityRole="button" accessibilityLabel="Playback speed">
          <Text style={styles.podcastBtnText}>{speed}×</Text>
        </Pressable>
      </View>
    </View>
  );
}

function formatPostDate(iso: string): string {
  const d = new Date(iso);
  const time = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  const date = d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
  return `${time} · ${date}`;
}

export default function PostReaderScreen() {
  const { itemId } = useLocalSearchParams<{ itemId?: string }>();
  const insets = useSafeAreaInsets();
  const showToast = useToast();
  const updateStatus = useUpdateItemStatus();

  const itemQ = useQuery({
    queryKey: ["postItem", itemId ?? ""],
    enabled: !!itemId,
    queryFn: async (): Promise<ItemWithAnalysis | null> => {
      const { data, error } = await supabase
        .from("items")
        .select("*, item_analysis(*)")
        .eq("id", itemId!)
        .single();
      if (error) throw error;
      // Instagram's video and photo links expire a few days after the post was
      // saved; expired ones are renewed before the post shows.
      return (await withFreshMedia(data as ItemWithAnalysis)) as ItemWithAnalysis;
    },
  });

  // Downloaded items open from the copy on the phone (works offline, and the
  // photos and episode don't download again). Status still comes from the
  // server when there's a connection.
  const savedOnPhone = useDownloadsStore((s) => (itemId ? !!s.entries[itemId] : false));
  const [localItem, setLocalItem] = useState<ItemWithAnalysis | null>(null);
  const [localChecked, setLocalChecked] = useState(false);
  useEffect(() => {
    let cancelled = false;
    if (!itemId) return;
    void readDownloadedItem(itemId).then((saved) => {
      if (cancelled) return;
      setLocalItem(saved);
      setLocalChecked(true);
    });
    return () => {
      cancelled = true;
    };
  }, [itemId, savedOnPhone]);

  const item = localItem ?? itemQ.data ?? null;
  // A private account's "new posts" card (e.g. opened from the email) shows
  // the profile inside the app instead.
  useEffect(() => {
    if (!item || !isNewPostsCard(item.video_id)) return;
    router.replace({
      pathname: "/profile-viewer",
      params: {
        url: item.url,
        name: (item.channel_name ?? "").replace(/\s*\(@[^)]*\)\s*$/, ""),
        platform: PLATFORM_META[platformOf(item.platform)].label,
      },
    });
  }, [item]);
  const [status, setStatus] = useState<ItemStatus>("not_watched");
  useEffect(() => {
    const source = itemQ.data ?? localItem;
    if (source) setStatus((source.user_status ?? "not_watched") as ItemStatus);
  }, [itemQ.data, localItem]);

  const changeStatus = (next: ItemStatus) => {
    if (!item || next === status) return;
    void Haptics.selectionAsync();
    const previous = status;
    setStatus(next);
    updateStatus.mutate(
      { id: item.id, status: next },
      {
        onError: () => {
          setStatus(previous);
          showToast("Couldn't update status", "error");
        },
      },
    );
  };

  if (!item) {
    return (
      <View style={[styles.screen, styles.center, { paddingTop: insets.top }]}>
        {itemQ.isError && localChecked ? (
          <>
            <Text style={styles.muted}>Couldn't load this post. Check your connection.</Text>
            <Pressable onPress={() => router.back()} style={[styles.openBtn, { paddingHorizontal: 20, marginTop: 16 }]}>
              <Text style={styles.openText}>Close</Text>
            </Pressable>
          </>
        ) : (
          <ActivityIndicator color={Colors.accent} />
        )}
      </View>
    );
  }

  const platform = platformOf(item.platform);
  const xPostId = item.video_id?.startsWith("x:") ? item.video_id.slice(2) : null;
  const tiktokVideoId = item.video_id?.startsWith("tiktok:") ? item.video_id.slice(7) : null;
  const liked = status === "liked";
  const bookmarked = status === "watch_later";
  const read = status === "watched";

  const share = () => {
    if (!item.url) return;
    void Share.share({ message: item.url, url: item.url });
  };
  const meta = PLATFORM_META[platform];
  const analysis = item.item_analysis?.[0] ?? null;
  const metrics = (item.metrics ?? {}) as PostMetrics;
  const embeds = (item.media ?? []) as PostEmbed[];
  const quote = embeds.find((m) => m.type === "quote" || m.type === "article") ?? null;
  const video = embeds.find((m) => m.type !== "quote" && m.type !== "article" && (m.video_url || m.hls_url)) ?? null;
  const appleRelease = platform === "apple_music" ? embeds.find((m) => m.type === "album" && m.embed_url) ?? null : null;
  // A Spotify artist's release: Spotify's own player (album or single).
  const spotifyRelease = platform === "spotify" ? embeds.find((m) => m.type === "album" && m.embed_url) ?? null : null;
  // Not matched to Spotify yet when it was saved: looked up again on open.
  const spotifyPendingSource = platform === "spotify" && !spotifyRelease
    ? embeds.find((m) => m.type === "album" && m.source_url)?.source_url ?? null
    : null;
  const ytMusic = platform === "youtube_music" ? embeds.find((m) => (m.type === "album" || m.type === "video") && (m.video_ids?.length || m.youtube_id)) ?? null : null;
  const ytMusicIds = ytMusic ? (ytMusic.video_ids?.length ? ytMusic.video_ids : ytMusic.youtube_id ? [ytMusic.youtube_id] : []) : [];
  const audiobook = platform === "apple_books" ? embeds.find((m) => m.type === "audiobook") ?? null : null;
  const podcastAudio = platform === "apple_podcasts" ? embeds.find((m) => m.type === "audio" && m.audio_url) ?? null : null;
  // Carousels (Instagram, LinkedIn) swipe through every photo.
  const photos = embeds.filter((m) => m.type !== "video" && m.type !== "quote" && m.type !== "article" && !!m.url);
  // Every photo and video in the post itself. More than one is a carousel.
  const slides = embeds.filter((m) => m.type !== "quote" && m.type !== "article" && (!!m.url || !!m.video_url || !!m.hls_url));
  const image =
    photos[0]?.url ??
    (!quote ? item.thumbnail_url : null) ??
    null;
  const keyPoints = analysis?.key_points ?? [];
  // Download for offline, in the action row next to Share / Save.
  const downloadButton = <DownloadButton itemId={item.id} hasAudio={!!podcastAudio} size={21} />;

  return (
    <View style={[styles.screen, { paddingTop: insets.top }]}>
      <View style={styles.header}>
        <Pressable onPress={() => router.back()} hitSlop={10} style={styles.headerBtn} accessibilityLabel="Close">
          <X size={22} color={Colors.textPrimary} />
        </Pressable>
        <View style={styles.headerMeta}>
          <PlatformBadge platform={platform} />
          <Text style={styles.headerText} numberOfLines={1}>
            {item.channel_name ?? meta.label}
            {item.published_at ? ` · ${timeAgo(item.published_at)}` : ""}
          </Text>
        </View>
      </View>

      <ScrollView contentContainerStyle={styles.content}>
        {platform === "reddit" || platform === "github" ? <Text style={styles.title}>{item.title}</Text> : null}
        {platform === "reddit" && item.author_handle ? (
          <Text style={styles.muted}>{item.author_handle}</Text>
        ) : null}

        {item.body ? (
          <Text style={platform === "reddit" ? styles.body : styles.bodyLarge}>{item.body}</Text>
        ) : null}

        {spotifyRelease?.embed_url ? (
          <View style={{ gap: 12 }}>
            <View style={[styles.appleEmbed, { height: spotifyRelease.embed_url.includes("/track/") ? 152 : 352 }]}>
              <WebView
                source={{ uri: spotifyRelease.embed_url }}
                style={{ flex: 1, backgroundColor: "transparent" }}
                allowsInlineMediaPlayback
                mediaPlaybackRequiresUserAction={false}
                javaScriptEnabled
                scrollEnabled={!spotifyRelease.embed_url.includes("/track/")}
                injectedJavaScriptBeforeContentLoaded={SPOTIFY_NO_DRM_JS}
            accessibilityLabel="Spotify player"
              />
            </View>
            {item.url ? (
              <Pressable
                onPress={() => void openExternalLink(item.url!)}
                style={({ pressed }) => [styles.openBtn, pressed && { opacity: 0.7 }]}
                accessibilityRole="link"
              >
                <SpotifyLogo />
                <Text style={styles.openText}>Open in Spotify</Text>
              </Pressable>
            ) : null}
          </View>
        ) : spotifyPendingSource ? (
          <SpotifyPendingRelease
            sourceUrl={spotifyPendingSource}
            title={item.title ?? ""}
            artistId={item.channel_id?.match(/^spotify:artist:([A-Za-z0-9]{22})$/)?.[1] ?? null}
            artistName={item.channel_name ?? null}
          />
        ) : ytMusic && ytMusicIds.length > 0 ? (
          <View style={{ gap: 12 }}>
            <YouTubeMusicPlayer videoIds={ytMusicIds} />
            <AddToYouTubeMusic videoIds={ytMusicIds} kind={ytMusic.type === "video" ? "video" : ytMusic.kind ?? "album"} />
            {item.url ? <SpotifySection sourceUrl={item.url} /> : null}
          </View>
        ) : appleRelease?.embed_url ? (
          <View style={{ gap: 12 }}>
            <AppleMusicPlayer embedUrl={appleRelease.embed_url} single={appleRelease.kind === "single"} />
            {item.video_id?.startsWith("apple_music:") ? (
              <AddToAppleMusic albumId={item.video_id.slice("apple_music:".length)} single={appleRelease.kind === "single"} />
            ) : null}
            {item.url ? <SpotifySection sourceUrl={item.url} /> : null}
          </View>
        ) : audiobook ? (
          <AudiobookCard media={audiobook} />
        ) : podcastAudio && item.video_id ? (
          <View style={{ gap: 12 }}>
            <PodcastPlayer
              media={podcastAudio}
              progressId={item.video_id}
              onFinished={() => { if (status === "not_watched") changeStatus("watched"); }}
            />
            <Pressable
              onPress={() => void openExternalLink(spotifyEpisodeSearchUrl(item.title ?? "", item.channel_name))}
              style={({ pressed }) => [styles.openBtn, pressed && { opacity: 0.7 }]}
              accessibilityRole="link"
            >
              <SpotifyLogo />
              <Text style={styles.openText}>Find on Spotify</Text>
            </Pressable>
          </View>
        ) : platform === "tiktok" && tiktokVideoId && photos.length === 0 ? (
          <TikTokPlayer videoId={tiktokVideoId} />
        ) : platform === "facebook" && video && !video.local_player && facebookEmbed(item.url) ? (
          <FacebookVideo media={video} postUrl={item.url} progressId={item.video_id} />
        ) : slides.length > 1 ? (
          <MediaCarousel slides={slides} progressId={item.video_id} />
        ) : video ? (
          <ExpandableMedia media={video} progressId={item.video_id} />
        ) : photos.length > 1 ? (
          <PhotoCarousel urls={photos.map((p) => p.url)} />
        ) : image ? (
          <ExpandableMedia media={{ type: "photo", url: image } as PostEmbed} />
        ) : null}

        {quote ? <QuoteCard quote={quote} /> : null}

        {analysis?.short_summary || keyPoints.length > 0 ? (
          <View style={styles.summaryBox}>
            <Text style={styles.summaryLabel}>{platform === "reddit" ? "THREAD SUMMARY" : "SUMMARY"}</Text>
            {analysis?.short_summary ? <Text style={styles.summaryText}>{analysis.short_summary}</Text> : null}
            {keyPoints.map((p) => (
              <Text key={p} style={styles.summaryPoint}>• {p}</Text>
            ))}
          </View>
        ) : null}

        {/* YouTube videos opened from Downloads: the key moments, to read offline. */}
        {platform === "youtube" && (analysis?.key_moments ?? []).length > 0 ? (
          <View style={styles.summaryBox}>
            <Text style={styles.summaryLabel}>KEY MOMENTS</Text>
            {(analysis?.key_moments ?? []).map((m) => (
              <Text key={`${m.seconds}-${m.text}`} style={styles.summaryPoint}>
                <Text style={{ color: Colors.accent, fontWeight: "700" }}>{formatClock(m.seconds)}</Text>  {m.text}
              </Text>
            ))}
          </View>
        ) : null}
      </ScrollView>

      <View style={[styles.footer, { paddingBottom: Math.max(insets.bottom, 12) }]}>
        {platform !== "reddit" && item.published_at ? (
          <Text style={styles.dateLine}>
            {platform === "x" ? formatPostDate(item.published_at) : formatPostDate(item.published_at).split(" · ")[1]}
            {metrics.views || metrics.plays ? (
              <>
                {" · "}
                <Text style={styles.dateLineStrong}>{formatCount(metrics.views || metrics.plays)}</Text> Views
              </>
            ) : null}
          </Text>
        ) : null}
        {platform === "instagram" ? (
          // Instagram: like, comment, share on the left; save on the right.
          <View style={styles.xBar}>
            <View style={styles.xBarEnd}>
              <BarButton
                label={liked ? "Remove from Saved" : "Like (save in My Feeds)"}
                selected={liked}
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                icon={<Heart size={22} color={liked ? IG_RED : Colors.textPrimary} fill={liked ? IG_RED : "transparent"} />}
                value={formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}
              />
              <BarButton
                label="Comment on Instagram"
                onPress={() => openExternalLink(item.url)}
                icon={<MessageCircle size={22} color={Colors.textPrimary} style={{ transform: [{ scaleX: -1 }] }} />}
                value={formatCount(metrics.comments)}
              />
              <BarButton label="Share" onPress={share} icon={<Send size={21} color={Colors.textPrimary} />} />
            </View>
            <View style={styles.barGroup}>
              {downloadButton}
              <BarButton
                label={bookmarked ? "Remove from Read Later" : "Save (Read Later)"}
                selected={bookmarked}
                onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
                icon={<Bookmark size={22} color={Colors.textPrimary} fill={bookmarked ? Colors.textPrimary : "transparent"} />}
              />
            </View>
          </View>
        ) : platform === "tiktok" ? (
          // TikTok: like, comment, save and share.
          <View style={styles.xBar}>
            <View style={{ flexDirection: "row", alignItems: "center" }}>
              <BarButton
                label={liked ? "Remove from Saved" : "Like (save in My Feeds)"}
                selected={liked}
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                icon={<Heart size={22} color={liked ? TIKTOK_RED : Colors.textPrimary} fill={liked ? TIKTOK_RED : "transparent"} />}
                value={formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}
              />
              <BarButton
                label="Comment on TikTok"
                onPress={() => { if (item.url) openExternalLink(item.url); }}
                icon={<MessageCircle size={22} color={Colors.textPrimary} style={{ transform: [{ scaleX: -1 }] }} />}
                value={formatCount(metrics.comments)}
              />
              <BarButton
                label={bookmarked ? "Remove from Read Later" : "Save (Read Later)"}
                selected={bookmarked}
                onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
                icon={<Bookmark size={22} color={bookmarked ? TIKTOK_YELLOW : Colors.textPrimary} fill={bookmarked ? TIKTOK_YELLOW : "transparent"} />}
                value={formatCount((metrics.bookmarks ?? 0) + (bookmarked ? 1 : 0))}
              />
            </View>
            <View style={styles.barGroup}>
              {downloadButton}
              <BarButton label="Share" onPress={share} icon={<Send size={21} color={Colors.textPrimary} />} value={formatCount(metrics.reposts)} />
            </View>
          </View>
        ) : platform === "apple_music" || platform === "apple_podcasts" || platform === "apple_books" || platform === "youtube_music" || platform === "spotify" ? (
          // Apple Music and Apple Podcasts: heart to save, share, save for later.
          <View style={styles.xBar}>
            <View style={{ flexDirection: "row", alignItems: "center" }}>
              <BarButton
                label={liked ? "Remove from Saved" : "Like (save in My Feeds)"}
                selected={liked}
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                icon={(() => {
                  const tint = platform === "apple_music" ? APPLE_MUSIC_RED : platform === "apple_books" ? APPLE_BOOKS_ORANGE : platform === "youtube_music" ? YOUTUBE_MUSIC_RED : platform === "spotify" ? SPOTIFY_GREEN : APPLE_PODCASTS_PURPLE;
                  return <Heart size={22} color={liked ? tint : Colors.textPrimary} fill={liked ? tint : "transparent"} />;
                })()}
              />
              <BarButton label="Share" onPress={share} icon={<ShareIcon size={21} color={Colors.textPrimary} />} />
            </View>
            <View style={styles.barGroup}>
              {downloadButton}
              <BarButton
                label={bookmarked ? "Remove from Later" : "Save for Later"}
                selected={bookmarked}
                onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
                icon={<Bookmark size={22} color={Colors.textPrimary} fill={bookmarked ? Colors.textPrimary : "transparent"} />}
              />
            </View>
          </View>
        ) : platform === "facebook" ? (
          // Facebook: reaction, comment and share counts, then Like, Comment, Share, plus Save.
          <View style={{ gap: 6 }}>
            <View style={styles.liCounts}>
              <View style={[styles.liLikeDot, { backgroundColor: FACEBOOK_BLUE }]}>
                <ThumbsUp size={9} color="#FFFFFF" fill="#FFFFFF" />
              </View>
              <Text style={styles.barText}>{formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}</Text>
              <Text style={[styles.barText, { marginLeft: "auto" }]}>
                {formatCount(metrics.comments)} comments{metrics.reposts ? ` · ${formatCount(metrics.reposts)} shares` : ""}
              </Text>
            </View>
            <View style={styles.liBar}>
              <LinkedInAction
                label="Like"
                active={liked}
                activeColor={FACEBOOK_BLUE}
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                icon={<ThumbsUp size={19} color={liked ? FACEBOOK_BLUE : Colors.textSecondary} fill={liked ? FACEBOOK_BLUE : "transparent"} />}
              />
              <LinkedInAction
                label="Comment"
                onPress={() => { if (item.url) openExternalLink(item.url); }}
                icon={<MessageCircle size={19} color={Colors.textSecondary} />}
              />
              <LinkedInAction label="Share" onPress={share} icon={<ShareIcon size={19} color={Colors.textSecondary} />} />
              <LinkedInAction
                label="Save"
                active={bookmarked}
                activeColor={FACEBOOK_BLUE}
                onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
                icon={<Bookmark size={19} color={bookmarked ? FACEBOOK_BLUE : Colors.textSecondary} fill={bookmarked ? FACEBOOK_BLUE : "transparent"} />}
              />
              <View style={{ marginLeft: "auto" }}>{downloadButton}</View>
            </View>
          </View>
        ) : platform === "linkedin" ? (
          // LinkedIn: Like, Comment, Repost, Send, plus Save.
          <View style={{ gap: 6 }}>
            <View style={styles.liCounts}>
              <View style={styles.liLikeDot}>
                <ThumbsUp size={9} color="#FFFFFF" fill="#FFFFFF" />
              </View>
              <Text style={styles.barText}>{formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}</Text>
              <Text style={[styles.barText, { marginLeft: "auto" }]}>
                {formatCount(metrics.comments)} comments · {formatCount(metrics.reposts)} reposts
              </Text>
            </View>
            <View style={styles.liBar}>
              <LinkedInAction
                label="Like"
                active={liked}
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                icon={<ThumbsUp size={19} color={liked ? LINKEDIN_BLUE : Colors.textSecondary} fill={liked ? LINKEDIN_BLUE : "transparent"} />}
              />
              <LinkedInAction label="Comment" onPress={() => openExternalLink(item.url)} icon={<MessageSquare size={19} color={Colors.textSecondary} />} />
              <LinkedInAction label="Repost" onPress={() => openExternalLink(item.url)} icon={<Repeat2 size={19} color={Colors.textSecondary} />} />
              <LinkedInAction label="Send" onPress={share} icon={<Send size={19} color={Colors.textSecondary} />} />
              <LinkedInAction
                label="Save"
                active={bookmarked}
                onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
                icon={<Bookmark size={19} color={bookmarked ? LINKEDIN_BLUE : Colors.textSecondary} fill={bookmarked ? LINKEDIN_BLUE : "transparent"} />}
              />
              <View style={{ marginLeft: "auto" }}>{downloadButton}</View>
            </View>
          </View>
        ) : platform === "x" ? (
          // X: reply, repost, like and bookmark on the left; download and share on the right.
          <View style={styles.xBar}>
            <View style={styles.barGroup}>
            <BarButton
              label="Reply on X"
              onPress={xPostId ? () => openExternalLink(`https://x.com/intent/post?in_reply_to=${xPostId}`) : undefined}
              icon={<MessageCircle size={19} color={Colors.textSecondary} />}
              value={formatCount(metrics.replies)}
            />
            <BarButton
              label="Repost on X"
              onPress={xPostId ? () => openExternalLink(`https://x.com/intent/retweet?tweet_id=${xPostId}`) : undefined}
              icon={<Repeat2 size={19} color={Colors.textSecondary} />}
              value={formatCount(metrics.reposts)}
            />
            <BarButton
              label={liked ? "Remove from Saved" : "Like (save in My Feeds)"}
              selected={liked}
              onPress={() => changeStatus(liked ? "watched" : "liked")}
              icon={<Heart size={19} color={liked ? X_PINK : Colors.textSecondary} fill={liked ? X_PINK : "transparent"} />}
              value={formatCount((metrics.likes ?? 0) + (liked ? 1 : 0))}
              valueColor={liked ? X_PINK : undefined}
            />
            <BarButton
              label={bookmarked ? "Remove from Read Later" : "Bookmark (Read Later)"}
              selected={bookmarked}
              onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
              icon={<Bookmark size={19} color={bookmarked ? X_BLUE : Colors.textSecondary} fill={bookmarked ? X_BLUE : "transparent"} />}
              value={formatCount((metrics.bookmarks ?? 0) + (bookmarked ? 1 : 0))}
              valueColor={bookmarked ? X_BLUE : undefined}
            />
            </View>
            <View style={styles.barGroup}>
              {downloadButton}
              <BarButton label="Share" onPress={share} icon={<ShareIcon size={19} color={Colors.textSecondary} />} />
            </View>
          </View>
        ) : platform === "github" ? (
          // GitHub: Star (= Saved), Fork and Save on the left; download and share on the right.
          <View style={styles.xBar}>
            <View style={styles.barGroup}>
            <BarButton
              label={liked ? "Remove from Saved" : "Star (save in My Feeds)"}
              selected={liked}
              onPress={() => changeStatus(liked ? "watched" : "liked")}
              icon={<Star size={19} color={liked ? GITHUB_STAR : Colors.textSecondary} fill={liked ? GITHUB_STAR : "transparent"} />}
              value={formatCount((metrics.stars ?? 0) + (liked ? 1 : 0))}
              valueColor={liked ? GITHUB_STAR : undefined}
            />
            <BarButton
              label="Fork on GitHub"
              onPress={() => openExternalLink(item.url)}
              icon={<GitFork size={19} color={Colors.textSecondary} />}
              value={formatCount(metrics.forks)}
            />
            <BarButton
              label={bookmarked ? "Remove from Read Later" : "Save (Read Later)"}
              selected={bookmarked}
              onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
              icon={<Bookmark size={19} color={bookmarked ? X_BLUE : Colors.textSecondary} fill={bookmarked ? X_BLUE : "transparent"} />}
            />
            </View>
            <View style={styles.barGroup}>
              {downloadButton}
              <BarButton label="Share" onPress={share} icon={<ShareIcon size={19} color={Colors.textSecondary} />} />
            </View>
          </View>
        ) : platform === "reddit" ? (
          <View style={styles.redditBar}>
            <View style={[styles.votePill, liked && { backgroundColor: REDDIT_ORANGE }]}>
              <Pressable
                onPress={() => changeStatus(liked ? "watched" : "liked")}
                style={styles.voteBtn}
                hitSlop={4}
                accessibilityRole="button"
                accessibilityLabel={liked ? "Remove upvote (Saved)" : "Upvote (save in My Feeds)"}
                accessibilityState={{ selected: liked }}
              >
                <ArrowBigUp size={22} color={liked ? "#FFFFFF" : Colors.textSecondary} fill={liked ? "#FFFFFF" : "transparent"} />
              </Pressable>
              <Text style={[styles.voteText, liked && { color: "#FFFFFF" }]}>
                {formatCount((metrics.score ?? 0) + (liked ? 1 : 0))}
              </Text>
              <Pressable
                onPress={() => changeStatus("watched")}
                style={styles.voteBtn}
                hitSlop={4}
                accessibilityRole="button"
                accessibilityLabel="Downvote (mark as read)"
              >
                <ArrowBigDown size={22} color={liked ? "#FFFFFF" : Colors.textSecondary} />
              </Pressable>
            </View>
            <Pressable
              onPress={() => openExternalLink(item.url)}
              style={styles.redditPill}
              accessibilityRole="button"
              accessibilityLabel="Open comments on Reddit"
            >
              <MessageSquare size={18} color={Colors.textPrimary} />
              <Text style={styles.redditPillText}>{formatCount(metrics.comments)}</Text>
            </Pressable>
            <Pressable
              onPress={() => changeStatus(bookmarked ? "not_watched" : "watch_later")}
              style={styles.redditPill}
              accessibilityRole="button"
              accessibilityLabel={bookmarked ? "Unsave (Read Later)" : "Save (Read Later)"}
              accessibilityState={{ selected: bookmarked }}
            >
              <Bookmark size={18} color={bookmarked ? X_BLUE : Colors.textPrimary} fill={bookmarked ? X_BLUE : "transparent"} />
              <Text style={[styles.redditPillText, bookmarked && { color: X_BLUE }]}>{bookmarked ? "Saved" : "Save"}</Text>
            </Pressable>
            <Pressable onPress={share} style={styles.redditPill} accessibilityRole="button" accessibilityLabel="Share">
              <ShareIcon size={18} color={Colors.textPrimary} />
              <Text style={styles.redditPillText}>Share</Text>
            </Pressable>
            <View style={{ marginLeft: "auto" }}>{downloadButton}</View>
          </View>
        ) : (
          // YouTube videos opened from Downloads: just the download icon.
          <View style={[styles.xBar, { justifyContent: "flex-end" }]}>{downloadButton}</View>
        )}

        <View style={styles.bottomRow}>
          <Pressable
            onPress={() => {
              // Marks it read and closes the post, back to the feed.
              if (!read) changeStatus("watched");
              router.back();
            }}
            style={({ pressed }) => [styles.openBtn, styles.bottomBtn, read && { borderColor: Colors.success }, pressed && { opacity: 0.7 }]}
            accessibilityRole="button"
            accessibilityState={{ selected: read }}
          >
            <Check size={16} color={read ? Colors.success : Colors.textPrimary} />
            <Text style={[styles.openText, read && { color: Colors.success }]}>{read ? "Read" : "Mark as read"}</Text>
          </Pressable>
          <Pressable
            onPress={() => openExternalLink(item.url)}
            style={({ pressed }) => [styles.openBtn, styles.bottomBtn, pressed && { opacity: 0.7 }]}
            accessibilityRole="link"
          >
            <ExternalLink size={16} color={Colors.textPrimary} />
            <Text style={styles.openText}>{meta.openLabel}</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

// Quoted post or X article, shown as a card inside the post like on X.
function QuoteCard({ quote }: { quote: PostEmbed }) {
  const isArticle = quote.type === "article";
  return (
    <Pressable
      onPress={() => openExternalLink(quote.url)}
      style={({ pressed }) => [styles.quoteCard, pressed && { opacity: 0.8 }]}
      accessibilityRole="link"
    >
      <View style={styles.quoteHeader}>
        {quote.author_avatar ? <Image source={{ uri: quote.author_avatar }} style={styles.quoteAvatar} /> : null}
        <Text style={styles.quoteName} numberOfLines={1}>{quote.author_name}</Text>
        {quote.verified ? <BadgeCheck size={15} color={X_BLUE} /> : null}
        <Text style={styles.quoteHandle} numberOfLines={1}>
          {quote.author_handle}
          {quote.created_at ? ` · ${timeAgo(quote.created_at)}` : ""}
        </Text>
      </View>
      {!isArticle && quote.text ? <Text style={styles.quoteText}>{quote.text}</Text> : null}
      {quote.video_url || quote.hls_url ? (
        <PostVideo media={{ ...quote, url: quote.image || "" }} />
      ) : quote.image ? (
        <Image source={{ uri: quote.image }} style={styles.quoteImage} contentFit="cover" />
      ) : null}
      {isArticle && quote.title ? <Text style={styles.quoteTitle}>{quote.title}</Text> : null}
      {isArticle && quote.preview ? (
        <Text style={styles.quoteText} numberOfLines={3}>{quote.preview}</Text>
      ) : null}
    </Pressable>
  );
}

// Swipeable row of photos for Instagram and LinkedIn carousels.
// Carousel posts (Instagram, LinkedIn, X with several photos): every photo and
// video in the post, swiped one page at a time, with a "2 / 5" counter and dots.
// Only the page on screen loads its video; the others show the poster with a
// play icon. The first video keeps the resume position (same id as web and iOS).
function MediaCarousel({ slides, progressId }: { slides: PostEmbed[]; progressId?: string | null }) {
  const { width } = useWindowDimensions();
  const pageWidth = Math.min(width, 720) - 32;
  const [page, setPage] = useState(0);
  const firstVideo = slides.findIndex((m) => !!(m.video_url || m.hls_url));
  // Page open in the full screen viewer (the inline video is paused meanwhile)
  const [viewerAt, setViewerAt] = useState<number | null>(null);
  return (
    <View style={{ gap: 6 }}>
      <View>
        <ScrollView
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / pageWidth))}
          style={{ width: pageWidth, borderRadius: 12 }}
        >
          {slides.map((m, i) => {
            const isVideo = !!(m.video_url || m.hls_url);
            const poster = m.url || m.image || "";
            return (
              <View key={i} style={[styles.carouselPage, { width: pageWidth }]}>
                {isVideo && i === page && viewerAt === null ? (
                  <PostVideo media={m} progressId={i === firstVideo ? progressId : null} />
                ) : (
                  <>
                    {poster ? (
                      <Pressable style={styles.carouselImage} onPress={() => setViewerAt(i)} accessibilityLabel="Open full screen">
                        <Image source={{ uri: poster }} style={styles.carouselImage} contentFit={isVideo ? "cover" : "contain"} />
                      </Pressable>
                    ) : null}
                    {isVideo ? (
                      <View style={styles.carouselPlay} pointerEvents="none">
                        <Play size={30} color="#fff" fill="#fff" />
                      </View>
                    ) : null}
                  </>
                )}
              </View>
            );
          })}
        </ScrollView>
        <View style={styles.carouselCounter} pointerEvents="none">
          <Text style={styles.carouselCounterText}>{page + 1} / {slides.length}</Text>
        </View>
        <Pressable style={styles.expandBtn} onPress={() => setViewerAt(page)} hitSlop={8} accessibilityLabel="Full screen">
          <Maximize2 size={16} color="#fff" />
        </Pressable>
      </View>
      <View style={styles.dots} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
        {slides.map((_, i) => (
          <View key={i} style={[styles.dot, i === page && styles.dotActive]} />
        ))}
      </View>
      {viewerAt !== null ? (
        <FullscreenViewer slides={slides} startIndex={viewerAt} progressId={progressId} onClose={() => setViewerAt(null)} />
      ) : null}
    </View>
  );
}

// A post's single video or photo, with the expand button (top left) that opens
// it full screen, like the YouTube player. Tapping a photo opens it too.
function ExpandableMedia({ media, progressId }: { media: PostEmbed; progressId?: string | null }) {
  const [open, setOpen] = useState(false);
  const isVideo = !!(media.video_url || media.hls_url);
  return (
    <View>
      {isVideo ? (
        // Paused (unmounted, position saved) while the full screen player is open
        open ? <View style={styles.video} /> : <PostVideo media={media} progressId={progressId} />
      ) : (
        <Pressable onPress={() => setOpen(true)} accessibilityLabel="Open photo full screen">
          <Image source={{ uri: media.url || media.image || "" }} style={styles.image} contentFit="cover" />
        </Pressable>
      )}
      <Pressable style={styles.expandBtn} onPress={() => setOpen(true)} hitSlop={8} accessibilityLabel="Full screen">
        <Maximize2 size={16} color="#fff" />
      </Pressable>
      {open ? (
        <FullscreenViewer slides={[media]} startIndex={0} progressId={progressId} onClose={() => setOpen(false)} />
      ) : null}
    </View>
  );
}

// Full screen viewer for a post's photos and videos: swipe between them, turn the
// phone for landscape, × to close. The video picks up where the inline one was
// (its position is saved when it pauses) and starts playing on its own.
function FullscreenViewer({ slides, startIndex, progressId, onClose }: { slides: PostEmbed[]; startIndex: number; progressId?: string | null; onClose: () => void }) {
  const { width, height } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const [page, setPage] = useState(startIndex);
  const firstVideoIndex = slides.findIndex((m) => !!(m.video_url || m.hls_url));
  return (
    <Modal
      visible
      animationType="fade"
      onRequestClose={onClose}
      supportedOrientations={["portrait", "landscape", "landscape-left", "landscape-right"]}
      statusBarTranslucent
    >
      <View style={styles.fullscreen}>
        <ScrollView
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          contentOffset={{ x: startIndex * width, y: 0 }}
          onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / width))}
        >
          {slides.map((m, i) => {
            const isVideo = !!(m.video_url || m.hls_url);
            const poster = m.url || m.image || "";
            return (
              <View key={i} style={{ width, height, alignItems: "center", justifyContent: "center" }}>
                {isVideo && i === page ? (
                  <PostVideo media={m} progressId={i === firstVideoIndex ? progressId : null} fill autoPlay />
                ) : poster ? (
                  <Image source={{ uri: poster }} style={{ width, height }} contentFit="contain" />
                ) : null}
              </View>
            );
          })}
        </ScrollView>
        <View style={[styles.fullscreenBar, { top: insets.top + 8, right: insets.right + 12 }]}>
          {slides.length > 1 ? (
            <View style={styles.fullscreenCounter}>
              <Text style={styles.carouselCounterText}>{page + 1} / {slides.length}</Text>
            </View>
          ) : null}
          <Pressable onPress={onClose} style={styles.fullscreenClose} hitSlop={10} accessibilityLabel="Close full screen">
            <X size={20} color="#fff" />
          </Pressable>
        </View>
      </View>
    </Modal>
  );
}

function PhotoCarousel({ urls }: { urls: string[] }) {
  const { width } = useWindowDimensions();
  const pageWidth = Math.min(width, 720) - 32;
  const [page, setPage] = useState(0);
  return (
    <View style={{ gap: 6 }}>
      <ScrollView
        horizontal
        pagingEnabled
        showsHorizontalScrollIndicator={false}
        onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / pageWidth))}
        style={{ width: pageWidth, borderRadius: 12 }}
      >
        {urls.map((u) => (
          <Image key={u} source={{ uri: u }} style={{ width: pageWidth, aspectRatio: 1, backgroundColor: Colors.card }} contentFit="cover" />
        ))}
      </ScrollView>
      <View style={styles.dots}>
        {urls.map((u, i) => (
          <View key={u} style={[styles.dot, i === page && styles.dotActive]} />
        ))}
      </View>
    </View>
  );
}

function LinkedInAction({ label, icon, active, activeColor = LINKEDIN_BLUE, onPress }: { label: string; icon: React.ReactNode; active?: boolean; activeColor?: string; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.liAction, pressed && { opacity: 0.6 }]}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ selected: !!active }}
    >
      {icon}
      <Text style={[styles.liActionText, active && { color: activeColor }]}>{label}</Text>
    </Pressable>
  );
}

function BarButton({
  label,
  icon,
  value,
  valueColor,
  selected,
  onPress,
}: {
  label: string;
  icon: React.ReactNode;
  value?: string;
  valueColor?: string;
  selected?: boolean;
  onPress?: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      disabled={!onPress}
      style={({ pressed }) => [styles.barBtn, pressed && { opacity: 0.6 }]}
      hitSlop={4}
      accessibilityRole="button"
      accessibilityLabel={label}
      accessibilityState={{ selected: !!selected }}
    >
      {icon}
      {value !== undefined ? <Text style={[styles.barText, valueColor ? { color: valueColor } : null]}>{value}</Text> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: Colors.background },
  center: { alignItems: "center", justifyContent: "center" },
  header: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: Colors.border,
  },
  headerBtn: { width: 44, height: 44, alignItems: "center", justifyContent: "center" },
  headerMeta: { flex: 1, flexDirection: "row", alignItems: "center", gap: 8 },
  headerText: { flex: 1, color: Colors.textSecondary, fontSize: 13, fontWeight: "600" },
  content: { padding: 16, gap: 14 },
  title: { color: Colors.textPrimary, fontSize: 19, fontWeight: "800", lineHeight: 25 },
  body: { color: Colors.textPrimary, fontSize: 15, lineHeight: 23 },
  bodyLarge: { color: Colors.textPrimary, fontSize: 17, lineHeight: 26 },
  muted: { color: Colors.textSecondary, fontSize: 13 },
  image: { width: "100%", aspectRatio: 16 / 9, borderRadius: 12, backgroundColor: Colors.card },
  summaryBox: {
    backgroundColor: "rgba(14, 165, 233, 0.10)",
    borderColor: "rgba(14, 165, 233, 0.25)",
    borderWidth: 1,
    borderRadius: 12,
    padding: 12,
    gap: 6,
  },
  summaryLabel: { color: Colors.accent, fontSize: 11, fontWeight: "800", letterSpacing: 0.8 },
  summaryText: { color: Colors.textPrimary, fontSize: 14, lineHeight: 21 },
  summaryPoint: { color: Colors.textPrimary, fontSize: 14, lineHeight: 21 },
  footer: {
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingHorizontal: 12,
    paddingTop: 10,
    gap: 10,
    backgroundColor: Colors.card,
  },
  xBar: { flexDirection: "row", alignItems: "center", justifyContent: "space-between" },
  barGroup: { flexDirection: "row", alignItems: "center" },
  xBarEnd: { flexDirection: "row", alignItems: "center" },
  dateLine: { color: Colors.textSecondary, fontSize: 13, paddingHorizontal: 4 },
  liCounts: { flexDirection: "row", alignItems: "center", gap: 5, paddingHorizontal: 4 },
  liLikeDot: { width: 16, height: 16, borderRadius: 8, backgroundColor: LINKEDIN_BLUE, alignItems: "center", justifyContent: "center" },
  liBar: {
    flexDirection: "row",
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: Colors.border,
    paddingTop: 4,
  },
  liAction: { alignItems: "center", justifyContent: "center", gap: 2, minHeight: 48, minWidth: 56, paddingHorizontal: 8 },
  liActionText: { color: Colors.textSecondary, fontSize: 11, fontWeight: "600" },
  dots: { flexDirection: "row", justifyContent: "center", gap: 5 },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: Colors.border },
  dotActive: { backgroundColor: Colors.accent },
  carouselPage: { aspectRatio: 1, backgroundColor: "#000", justifyContent: "center", alignItems: "center" },
  carouselImage: { width: "100%", height: "100%" },
  carouselPlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(0,0,0,0.25)",
  },
  carouselCounter: {
    position: "absolute",
    top: 10,
    right: 10,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
    backgroundColor: "rgba(0,0,0,0.6)",
  },
  carouselCounterText: { color: "#fff", fontSize: 12, fontWeight: "600" },
  dateLineStrong: { color: Colors.textPrimary, fontWeight: "700" },
  video: { width: "100%", aspectRatio: 16 / 9, borderRadius: 12, overflow: "hidden", backgroundColor: "#000" },
  tiktokWrap: { alignItems: "center", borderRadius: 12, overflow: "hidden", backgroundColor: "#000" },
  videoFill: { width: "100%", height: "100%", backgroundColor: "#000" },
  appleEmbed: { width: "100%", borderRadius: 12, overflow: "hidden" },
  podcastCard: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 12,
    backgroundColor: Colors.card,
    padding: 12,
    gap: 10,
  },
  podcastTop: { flexDirection: "row", alignItems: "center", gap: 12 },
  podcastArt: { width: 72, height: 72, borderRadius: 10 },
  audiobookCover: { width: 96, height: 96, borderRadius: 8 },
  audiobookLabel: { color: APPLE_BOOKS_ORANGE, fontSize: 11, fontWeight: "800" as const, letterSpacing: 0.6 },
  podcastResume: { color: Colors.textPrimary, fontSize: 13, fontWeight: "600" as const },
  podcastAudio: { height: 56 },
  podcastControls: { flexDirection: "row", justifyContent: "center", gap: 8 },
  podcastBtn: {
    borderWidth: 1,
    borderColor: Colors.border,
    borderRadius: 8,
    paddingHorizontal: 12,
    paddingVertical: 8,
    minHeight: 40,
    justifyContent: "center",
  },
  podcastBtnText: { color: Colors.textPrimary, fontSize: 13, fontWeight: "700" as const },
  expandBtn: {
    position: "absolute",
    top: 10,
    left: 10,
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(0,0,0,0.6)",
  },
  fullscreen: { flex: 1, backgroundColor: "#000" },
  fullscreenBar: { position: "absolute", flexDirection: "row", alignItems: "center", gap: 10 },
  fullscreenCounter: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14, backgroundColor: "rgba(0,0,0,0.6)" },
  fullscreenClose: {
    width: 36,
    height: 36,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(0,0,0,0.6)",
  },
  videoWeb: { flex: 1, backgroundColor: "#000" },
  quoteCard: { borderWidth: 1, borderColor: Colors.border, borderRadius: 16, padding: 12, gap: 8 },
  quoteHeader: { flexDirection: "row", alignItems: "center", gap: 6 },
  quoteAvatar: { width: 20, height: 20, borderRadius: 10 },
  quoteName: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700", flexShrink: 1 },
  quoteHandle: { color: Colors.textSecondary, fontSize: 14, flexShrink: 1 },
  quoteText: { color: Colors.textPrimary, fontSize: 14, lineHeight: 20 },
  quoteTitle: { color: Colors.textPrimary, fontSize: 15, fontWeight: "800", lineHeight: 21 },
  quoteImage: { width: "100%", aspectRatio: 16 / 9, borderRadius: 12, backgroundColor: Colors.card },
  barBtn: { flexDirection: "row", alignItems: "center", gap: 5, minHeight: 44, minWidth: 36, paddingHorizontal: 4 },
  barText: { color: Colors.textSecondary, fontSize: 13, fontVariant: ["tabular-nums"] },
  redditBar: { flexDirection: "row", alignItems: "center", flexWrap: "wrap", gap: 8 },
  votePill: { flexDirection: "row", alignItems: "center", height: 40, borderRadius: 20, backgroundColor: Colors.input },
  voteBtn: { width: 40, height: 40, alignItems: "center", justifyContent: "center" },
  voteText: { color: Colors.textPrimary, fontSize: 13, fontWeight: "700", fontVariant: ["tabular-nums"] },
  redditPill: {
    flexDirection: "row",
    alignItems: "center",
    gap: 6,
    height: 40,
    paddingHorizontal: 14,
    borderRadius: 20,
    backgroundColor: Colors.input,
  },
  redditPillText: { color: Colors.textPrimary, fontSize: 13, fontWeight: "700" },
  bottomRow: { flexDirection: "row", gap: 8 },
  bottomBtn: { flex: 1 },
  openBtn: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    height: 44,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: Colors.border,
  },
  openText: { color: Colors.textPrimary, fontSize: 14, fontWeight: "700" },
});
