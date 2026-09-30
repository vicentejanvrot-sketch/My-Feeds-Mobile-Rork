import { supabase } from "@/lib/supabase";

// When the onboarding wizard opens by itself. It opens once per app launch
// until the user ticks "Don't show this again". That choice is saved on the
// user's auth metadata ("hide_onboarding"), the same key the web and iOS apps
// use, so it follows the user to every device.

export const HIDE_ONBOARDING_KEY = "hide_onboarding";

let shownThisLaunch = false;

export function markOnboardingShown() {
  shownThisLaunch = true;
}

/** True when the wizard should open by itself on the Dashboard. */
export async function shouldAutoOpenOnboarding(): Promise<boolean> {
  if (shownThisLaunch) return false;
  // Read the user fresh, in case they ticked the box on another device.
  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return false;
  if (data.user.user_metadata?.[HIDE_ONBOARDING_KEY] === true) return false;
  return !shownThisLaunch;
}

/** Saves "Don't show this again". Returns an error message, or null when saved. */
export async function setOnboardingHidden(hidden: boolean): Promise<string | null> {
  const { error } = await supabase.auth.updateUser({ data: { [HIDE_ONBOARDING_KEY]: hidden } });
  return error ? error.message : null;
}
