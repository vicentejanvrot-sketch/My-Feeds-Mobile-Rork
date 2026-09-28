// Resume position for every video the app plays: YouTube (video-player) and the
// X / Instagram / Reddit videos in the post reader. Same rules and the same
// video_progress table as the web and iOS apps, keyed by the item's video_id
// (a YouTube id, or "x:…", "instagram:…", "reddit:…" for posts).
import AsyncStorage from "@react-native-async-storage/async-storage";
import { supabase } from "@/lib/supabase";

export const POSITION_SAVE_INTERVAL_MS = 5000;
// Same rules as the web and iOS apps: resume only from a few seconds in, and a
// position in the last few seconds counts as finished (cleared, never saved).
// Long videos use 5 s and 10 s; short clips (X, Instagram) get proportional
// limits (10% / 5% of the length) so a 20-second clip still resumes.
export const MIN_RESUME_SECONDS = 5;
export const END_THRESHOLD_SECONDS = 10;

export function minResumeSeconds(duration: number): number {
  return duration > 0 ? Math.min(MIN_RESUME_SECONDS, duration * 0.1) : MIN_RESUME_SECONDS;
}

export function isNearEnd(position: number, duration: number): boolean {
  return duration > 0 && position >= duration - Math.min(END_THRESHOLD_SECONDS, duration * 0.05);
}

export interface SavedPosition {
  currentTime: number;
  duration: number;
  updatedAt: number;
}

function resumePositionKey(videoId: string): string {
  return `@video_position/${videoId}`;
}

// Positions are kept on the phone (AsyncStorage) and in the shared
// video_progress table, which the web app uses too. Opening a video resumes
// from whichever of the two was saved most recently, so switching between
// web and mobile doesn't restart the video.

async function getUserId(): Promise<string | null> {
  try {
    const { data } = await supabase.auth.getSession();
    return data.session?.user?.id ?? null;
  } catch {
    return null;
  }
}

async function saveRemotePosition(videoId: string, data: SavedPosition): Promise<void> {
  const userId = await getUserId();
  if (!userId) return;
  try {
    await supabase.from("video_progress").upsert(
      {
        user_id: userId,
        video_id: videoId,
        position_seconds: data.currentTime,
        duration_seconds: data.duration,
        updated_at: new Date(data.updatedAt).toISOString(),
      },
      { onConflict: "user_id,video_id" },
    );
  } catch {
    // Silently ignore: the local copy is still saved
  }
}

async function loadRemotePosition(videoId: string): Promise<SavedPosition | null> {
  const userId = await getUserId();
  if (!userId) return null;
  try {
    const { data, error } = await supabase
      .from("video_progress")
      .select("position_seconds, duration_seconds, updated_at")
      .eq("user_id", userId)
      .eq("video_id", videoId)
      .maybeSingle();
    if (error || !data) return null;
    return {
      currentTime: Number(data.position_seconds) || 0,
      duration: Number(data.duration_seconds) || 0,
      updatedAt: new Date(data.updated_at).getTime() || 0,
    };
  } catch {
    return null;
  }
}

export async function saveResumePosition(
  videoId: string,
  currentTime: number,
  duration: number,
): Promise<void> {
  if (!videoId || duration <= 0 || currentTime <= 0) return;
  // Don't bring back a finished video's position (the end clears it).
  if (isNearEnd(currentTime, duration)) return;
  const data: SavedPosition = {
    currentTime,
    duration,
    updatedAt: Date.now(),
  };
  try {
    await AsyncStorage.setItem(resumePositionKey(videoId), JSON.stringify(data));
  } catch {
    // Silently ignore write failures
  }
  await saveRemotePosition(videoId, data);
}

export async function loadResumePosition(
  videoId: string,
): Promise<SavedPosition | null> {
  if (!videoId) return null;
  let local: SavedPosition | null = null;
  try {
    const raw = await AsyncStorage.getItem(resumePositionKey(videoId));
    if (raw) {
      const data = JSON.parse(raw) as SavedPosition;
      if (
        typeof data.currentTime === "number" &&
        typeof data.duration === "number"
      ) {
        local = data;
      }
    }
  } catch {
    local = null;
  }
  const remote = await loadRemotePosition(videoId);
  if (!remote) return local;
  if (!local) return remote;
  return (remote.updatedAt || 0) > (local.updatedAt || 0) ? remote : local;
}

export async function clearResumePosition(videoId: string): Promise<void> {
  if (!videoId) return;
  try {
    await AsyncStorage.removeItem(resumePositionKey(videoId));
  } catch {
    // Silently ignore
  }
  const userId = await getUserId();
  if (!userId) return;
  try {
    await supabase
      .from("video_progress")
      .delete()
      .eq("user_id", userId)
      .eq("video_id", videoId);
  } catch {
    // Silently ignore
  }
}
