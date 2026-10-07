import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import { getLocales } from "expo-localization";
import AsyncStorage from "@react-native-async-storage/async-storage";
import { create } from "zustand";
import { enUS } from "date-fns/locale/en-US";
import { ptBR } from "date-fns/locale/pt-BR";
import type { Locale as DateFnsLocale } from "date-fns";
import en from "./locales/en.json";
import ptBRStrings from "./locales/pt-BR.json";

// App UI languages. English is the source and the fallback.
export const LANGUAGES = ["en", "pt-BR"] as const;
export type AppLanguage = (typeof LANGUAGES)[number];

// What the user picked in Settings. "auto" follows the device language.
export type LanguagePreference = "auto" | AppLanguage;

// Saved on this device only, never in the database.
const STORAGE_KEY = "@settings/language";

type Dict = { [key: string]: string | Dict };

/**
 * Portuguese plural forms. Where Intl.PluralRules exists (web), pt-BR maps 0
 * to "one" and very large numbers to "many"; Hermes has no PluralRules and
 * i18next falls back to one/other. Copy "_other" into "_zero" and "_many" so
 * every platform reads "0 vídeos" and "1.000.000 vídeos".
 */
function fillPortuguesePlurals(dict: Dict): Dict {
  const out: Dict = {};
  for (const [key, value] of Object.entries(dict)) {
    out[key] = typeof value === "string" ? value : fillPortuguesePlurals(value);
  }
  for (const [key, value] of Object.entries(dict)) {
    if (typeof value !== "string" || !key.endsWith("_other")) continue;
    const base = key.slice(0, -"_other".length);
    if (!(base + "_zero" in out)) out[base + "_zero"] = value;
    if (!(base + "_many" in out)) out[base + "_many"] = value;
  }
  return out;
}

/** Any Portuguese device locale gets pt-BR; everything else gets English. */
export function deviceLanguage(): AppLanguage {
  try {
    const first = getLocales()[0];
    const code = (first?.languageCode ?? first?.languageTag ?? "").toLowerCase();
    return code.startsWith("pt") ? "pt-BR" : "en";
  } catch {
    return "en";
  }
}

function resolve(pref: LanguagePreference): AppLanguage {
  return pref === "auto" ? deviceLanguage() : pref;
}

void i18n.use(initReactI18next).init({
  resources: {
    en: { translation: en },
    "pt-BR": { translation: fillPortuguesePlurals(ptBRStrings as Dict) },
  },
  lng: deviceLanguage(),
  fallbackLng: "en",
  supportedLngs: [...LANGUAGES],
  interpolation: { escapeValue: false },
  returnNull: false,
  react: { useSuspense: false },
});

// ── User preference ──────────────────────────────────────────────

interface LanguageState {
  preference: LanguagePreference;
  loaded: boolean;
}

export const useLanguageStore = create<LanguageState>(() => ({
  preference: "auto",
  loaded: false,
}));

/** Reads the saved choice once at startup and applies it. */
export async function loadLanguagePreference(): Promise<void> {
  let pref: LanguagePreference = "auto";
  try {
    const saved = await AsyncStorage.getItem(STORAGE_KEY);
    if (saved === "en" || saved === "pt-BR") pref = saved;
  } catch {
    // Storage unavailable: keep following the device.
  }
  useLanguageStore.setState({ preference: pref, loaded: true });
  const lng = resolve(pref);
  if (i18n.language !== lng) await i18n.changeLanguage(lng);
}

/** Saves the choice and switches the UI right away. */
export async function setLanguagePreference(pref: LanguagePreference): Promise<void> {
  useLanguageStore.setState({ preference: pref, loaded: true });
  await i18n.changeLanguage(resolve(pref));
  try {
    if (pref === "auto") await AsyncStorage.removeItem(STORAGE_KEY);
    else await AsyncStorage.setItem(STORAGE_KEY, pref);
  } catch {
    // Not saved; the choice still applies until the app restarts.
  }
}

/** Re-checks the device language (Android can change it while the app runs). */
export function syncDeviceLanguage(): void {
  if (useLanguageStore.getState().preference !== "auto") return;
  const lng = deviceLanguage();
  if (i18n.language !== lng) void i18n.changeLanguage(lng);
}

// ── Formatting helpers ───────────────────────────────────────────

export function currentLanguage(): AppLanguage {
  return i18n.language === "pt-BR" ? "pt-BR" : "en";
}

/** Locale tag for Intl / toLocale* calls. */
export function intlLocale(): string {
  return currentLanguage() === "pt-BR" ? "pt-BR" : "en-US";
}

/** date-fns locale for the active language. */
export function dateLocale(): DateFnsLocale {
  return currentLanguage() === "pt-BR" ? ptBR : enUS;
}

/** 12345 -> "12,345" / "12.345". */
export function formatNumber(n: number): string {
  try {
    return n.toLocaleString(intlLocale());
  } catch {
    return String(n);
  }
}

export default i18n;
