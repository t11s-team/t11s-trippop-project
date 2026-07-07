/**
 * Auth API. Works in both modes now that the backend has password hashing,
 * a token-returning signup, and a /signin endpoint (BACKEND_REVIEW #1/#2/#3 fixed).
 *   - mock mode: signup/signin against the in-memory store
 *   - real mode: user-service POST /signup/request and POST /signin
 */
import { USE_MOCK, API, MOCK_LATENCY } from "../config.js";
import { request, ApiError } from "./client.js";
import { mockStore } from "../mocks/store.js";

const delay = (ms) => new Promise((r) => setTimeout(r, ms));

export async function signUp({ name, email, password, language = "ko" }) {
  if (USE_MOCK) {
    await delay(MOCK_LATENCY);
    if (mockStore.findByEmail(email)) {
      throw new ApiError("An account with this email already exists.", 409);
    }
    const user = mockStore.createUser({ email, name, language });
    return { token: user.token, user };
  }

  // Real backend hashes the password and returns { token, user }.
  return request(`${API.user}/users/signup/request`, {
    method: "POST",
    body: { email, name, password, language },
  });
}

export async function signIn({ email, password }) {
  if (USE_MOCK) {
    await delay(MOCK_LATENCY);
    const user = mockStore.findByEmail(email);
    if (!user) {
      throw new ApiError("No account found for this email. Try signing up.", 404);
    }
    // Mock has no password store; any password is accepted (real mode verifies).
    return { token: user.token, user };
  }

  // Real backend verifies the bcrypt hash and returns a freshly rotated token.
  return request(`${API.user}/users/signin`, {
    method: "POST",
    body: { email, password },
  });
}
