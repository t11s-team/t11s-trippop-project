/** Pure formatting helpers. No side effects, no mutation. */

import { t } from "./i18n.js";

/** Pad to two digits. */
const pad = (n) => String(n).padStart(2, "0");

/** Format milliseconds remaining as HH:MM:SS (clamped at zero). */
export function formatCountdown(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return `${pad(h)}:${pad(m)}:${pad(s)}`;
}

const DAY_KEYS = [
  "date.day.sun",
  "date.day.mon",
  "date.day.tue",
  "date.day.wed",
  "date.day.thu",
  "date.day.fri",
  "date.day.sat",
];

/**
 * Localised "month day (day)" label, e.g.
 *   ko: "5월 6일 (월)"
 *   en: "May 6 (Mon)"
 *   zh: "5月6日 (周一)"
 *   ar: "٦ مايو (الإثنين)"
 *
 * Uses Intl.DateTimeFormat for the month + day so each locale gets the right
 * script, ordering, and (for Arabic) numerals. Falls back to the ISO string
 * if the input cannot be parsed.
 *
 * `lang` is required — pass `lang` from useLanguage() at the call site.
 */
export function formatDateLabel(iso, lang = "ko") {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;

  const locale =
    lang === "ko" ? "ko-KR" :
    lang === "zh" ? "zh-CN" :
    lang === "ar" ? "ar-EG" : "en-US";

  const monthDay = new Intl.DateTimeFormat(locale, {
    month: "short",
    day: "numeric",
  }).format(d);

  const dayShort = t(DAY_KEYS[d.getDay()], lang);
  return `${monthDay} (${dayShort})`;
}

/** Localised 24h time "HH:MM" from an ISO datetime. */
export function formatTime(iso, lang = "ko") {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const locale =
    lang === "ko" ? "ko-KR" :
    lang === "zh" ? "zh-CN" :
    lang === "ar" ? "ar-EG" : "en-US";
  return new Intl.DateTimeFormat(locale, {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(d);
}
