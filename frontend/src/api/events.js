/**
 * Events API. Mock mode returns the rich catalogue the UI needs. Real mode
 * calls event-service and adapts its rows to the UI shape, backfilling the
 * fields the schema doesn't have yet (hours / offer / map / gallery).
 */
import { USE_MOCK, API, MOCK_LATENCY } from "../config.js";
import { request } from "./client.js";
import { EVENTS, findEvent } from "../mocks/events.js";
import { formatDateLabel } from "../lib/format.js";

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

// Display-only fields the backend has no columns for yet.
const DISPLAY_DEFAULTS = {
  // image_url 이 비어있을 때만 쓰는 최후 폴백. 시드엔 항상 image_url 이 있어 실제론 거의 안 탐.
  image: "/mock/popup-fennec.svg",
  dateRange: "Dates to be announced",
  hours: "See details",
  price: "Free Reservation",
  offer: "Special offer",
  // map/gallery 기본값 제거: EventDetail 에서 지도 이미지·갤러리 섹션을 없앴으므로 더는
  // 참조되지 않는다. (예전 번들이 이 /mock SVG 들을 상세에 띄우던 원인이었음)
};

const badgeFor = (category) => (category || "EVENT").toUpperCase();
const isLimited = (slotsLeft) => slotsLeft > 0 && slotsLeft <= 5;

// event-service GET /events row -> Home card shape
function adaptListRow(row, lang) {
  const slotsLeft = Number(row.slots_left ?? 0);
  return {
    ...DISPLAY_DEFAULTS,
    id: row.id,
    title: row.title,
    category: row.category,
    badge: badgeFor(row.category),
    // 카드 1줄 설명 = 제목과 동일.
    subtitle: row.title,
    description: row.description || "",
    location: row.location || "",
    image: row.image_url || DISPLAY_DEFAULTS.image,
    slotsLeft,
    limited: isLimited(slotsLeft),
    dateRange: row.next_slot ? formatDateLabel(row.next_slot, lang) : DISPLAY_DEFAULTS.dateRange,
  };
}

// event-service GET /events/:id row -> Detail shape
function adaptDetailRow(row, lang) {
  const slots = row.slots || [];
  const slotsLeft = slots.reduce((sum, s) => sum + Number(s.remaining_capacity || 0), 0);
  return {
    ...DISPLAY_DEFAULTS,
    id: row.id,
    title: row.title,
    category: row.category,
    badge: badgeFor(row.category),
    // 한줄 소개(subtitle) = 제목. 긴 서술 전체는 description(이벤트 상세 섹션)로.
    subtitle: row.title,
    description: row.description || "",
    location: row.location || "",
    image: row.image_url || DISPLAY_DEFAULTS.image,
    mainImage: row.main_image_url || row.image_url || DISPLAY_DEFAULTS.image,
    dateRange: slots[0] ? formatDateLabel(slots[0].slot_datetime, lang) : DISPLAY_DEFAULTS.dateRange,
    slotsLeft,
    limited: isLimited(slotsLeft),
    slots,
  };
}

export async function listEvents({ lang = "ko" } = {}) {
  if (USE_MOCK) {
    await delay(MOCK_LATENCY);
    return EVENTS;
  }
  const rows = await request(`${API.event}/events?lang=${encodeURIComponent(lang)}`);
  return (rows || []).map((row) => adaptListRow(row, lang));
}

export async function getEvent(id, { lang = "ko" } = {}) {
  if (USE_MOCK) {
    await delay(MOCK_LATENCY);
    const event = findEvent(id);
    if (!event) throw new Error("Event not found");
    return event;
  }
  const row = await request(`${API.event}/events/${id}?lang=${encodeURIComponent(lang)}`);
  return adaptDetailRow(row, lang);
}
