import i18n, { formatNumber, intlLocale } from "@/lib/i18n";

/** Relative time like "3h ago", "2d ago" ("há 3 h", "há 2 d"). */
export function timeAgo(iso: string | null): string {
  if (!iso) return "—";
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return "—";
  const diff = Date.now() - then;
  const sec = Math.round(diff / 1000);
  if (sec < 60) return i18n.t("time.justNow");
  const min = Math.round(sec / 60);
  if (min < 60) return i18n.t("time.short.minutes", { count: min });
  const hr = Math.round(min / 60);
  if (hr < 24) return i18n.t("time.short.hours", { count: hr });
  const day = Math.round(hr / 24);
  if (day < 30) return i18n.t("time.short.days", { count: day });
  const mo = Math.round(day / 30);
  if (mo < 12) return i18n.t("time.short.months", { count: mo });
  return i18n.t("time.short.years", { count: Math.round(mo / 12) });
}

/** Human relative time like "about 3 hours ago" ("há cerca de 3 horas"). */
export function relativeTime(iso: string | null): string {
  if (!iso) return "—";
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return "—";
  const diff = Date.now() - then;
  const sec = Math.round(diff / 1000);
  if (sec < 10) return i18n.t("time.justNow");
  if (sec < 60) return i18n.t("time.long.lessThanMinute");
  const min = Math.round(sec / 60);
  if (min < 60) return i18n.t("time.long.minutes", { count: min });
  const hr = Math.round(min / 60);
  if (hr < 24) return i18n.t("time.long.hours", { count: hr });
  const day = Math.round(hr / 24);
  if (day < 30) return i18n.t("time.long.days", { count: day });
  const mo = Math.round(day / 30);
  if (mo < 12) return i18n.t("time.long.months", { count: mo });
  return i18n.t("time.long.years", { count: Math.round(mo / 12) });
}

function decimal(n: number, digits: number): string {
  try {
    return n.toLocaleString(intlLocale(), { minimumFractionDigits: digits, maximumFractionDigits: digits });
  } catch {
    return n.toFixed(digits);
  }
}

/** Compact count like 1.2K, 3.4M (1,2 mil, 3,4 mi). */
export function compactNumber(n: number | null | undefined): string {
  if (n == null) return "—";
  if (n < 1000) return formatNumber(n);
  if (n < 1_000_000) {
    return i18n.t("format.thousands", { value: decimal(n / 1000, n < 10_000 ? 1 : 0) });
  }
  return i18n.t("format.millions", { value: decimal(n / 1_000_000, n < 10_000_000 ? 1 : 0) });
}

/** Seconds → "12:34" or "1:02:03". */
export function formatDuration(seconds: number | null | undefined): string {
  if (!seconds || seconds <= 0) return "—";
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  const pad = (x: number) => String(x).padStart(2, "0");
  return h > 0 ? `${h}:${pad(m)}:${pad(s)}` : `${m}:${pad(s)}`;
}
