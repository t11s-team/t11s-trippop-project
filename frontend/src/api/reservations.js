/**
 * Reservations API. Talks to reservation-service:
 *   - POST /reserve   ({ slot_id } + bearer token + `x-idempotency-key` header)
 *   - GET  /reservations (list current user's reservations)
 * Mock mode replicates the same contract offline.
 */
import { USE_MOCK, API, MOCK_LATENCY } from "../config.js";
import { request } from "./client.js";
import { uuid } from "../lib/id.js";
import { mockStore } from "../mocks/store.js";
import { formatDateLabel, formatTime } from "../lib/format.js";

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * @param {object} args
 * @param {object} args.auth  - { token, user }
 * @param {object} args.slot  - chosen event_slot (with id, capacity, label...)
 * @param {string} [args.idempotencyKey] - reuse to retry safely
 */
export async function reserve({ auth, slot, idempotencyKey = uuid() }) {
  if (USE_MOCK) {
    await delay(MOCK_LATENCY);
    const reservation = mockStore.createReservation({
      userId: auth.user.id,
      slot,
      idempotencyKey,
    });
    return {
      reservation_id: reservation.id,
      slot_id: reservation.event_slot_id,
      status: reservation.status,
      idempotent: Boolean(reservation.idempotent),
    };
  }

  return request(`${API.reservation}/reservations`, {
    method: "POST",
    token: auth.token,
    headers: { "x-idempotency-key": idempotencyKey },
    body: { slot_id: slot.id },
  });
}

export async function listMyReservations({ auth, lang = "ko" }) {
  if (USE_MOCK) {
    await delay(MOCK_LATENCY);
    return mockStore.getReservations(auth.user.id);
  }

  const rows = await request(
    `${API.reservation}/reservations?lang=${encodeURIComponent(lang)}`,
    { token: auth.token }
  );
  return (rows || []).map((r) => ({
    id: r.id,
    status: r.status,
    event_id: r.event_id,
    event_title: r.event_title,
    event_image: r.event_image,
    slot_label: `${formatDateLabel(r.slot_datetime, lang)} · ${formatTime(r.slot_datetime, lang)}`,
  }));
}
