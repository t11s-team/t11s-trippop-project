/**
 * In-memory + localStorage mock backend. Stands in for user/reservation
 * services so the full flow works offline. Mirrors the seed data in
 * scripts/db_seed.sql (same demo users + tokens).
 */
import { uuid } from "../lib/id.js";

const USERS_KEY = "trippop.mock.users";
const RES_KEY = "trippop.mock.reservations";

const SEED_USERS = [
  { id: 3, email: "emma@test.com", name: "Emma", language: "en", token: "11111111-1111-1111-1111-111111111111" },
  { id: 1, email: "kim@example.com", name: "Kim Gil-dong", language: "en", token: "550e8400-e29b-41d4-a716-446655440000" },
];

function read(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Safari private mode / storage quota / iframe restrictions throw here.
    // The mock store keeps working in-memory for the current tab; data just
    // won't survive reload. Better than crashing the whole signup flow.
  }
}

export const mockStore = {
  getUsers() {
    return read(USERS_KEY, SEED_USERS);
  },

  findByEmail(email) {
    return this.getUsers().find((u) => u.email.toLowerCase() === email.toLowerCase());
  },

  findByToken(token) {
    return this.getUsers().find((u) => u.token === token);
  },

  // Immutable add — returns a brand new user record.
  createUser({ email, name, language = "en" }) {
    const users = this.getUsers();
    const user = {
      id: users.length ? Math.max(...users.map((u) => u.id)) + 1 : 1,
      email,
      name,
      language,
      token: uuid(),
    };
    write(USERS_KEY, [...users, user]);
    return user;
  },

  getReservations(userId) {
    return read(RES_KEY, []).filter((r) => r.user_id === userId);
  },

  // Enforces the same uniqueness contract as the DB (one reservation per
  // user+slot) so the mock flow matches reservation-service semantics.
  createReservation({ userId, slot, idempotencyKey }) {
    const all = read(RES_KEY, []);

    const byKey = all.find((r) => r.idempotency_key === idempotencyKey);
    if (byKey) return { ...byKey, idempotent: true };

    const dup = all.find((r) => r.user_id === userId && r.event_slot_id === slot.id);
    if (dup) {
      const err = new Error("이미 예약하셨습니다");
      err.status = 409;
      throw err;
    }
    if (slot.remaining_capacity <= 0) {
      const err = new Error("마감되었습니다");
      err.status = 409;
      throw err;
    }

    const reservation = {
      id: all.length ? Math.max(...all.map((r) => r.id)) + 1 : 1,
      user_id: userId,
      event_slot_id: slot.id,
      event_id: slot.event_id,
      status: "confirmed",
      idempotency_key: idempotencyKey,
      created_at: new Date().toISOString(),
      slot_label: slot.label,
      event_title: slot.event_title,
      event_image: slot.event_image,
    };
    write(RES_KEY, [...all, reservation]);
    return reservation;
  },
};
