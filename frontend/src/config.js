/**
 * Runtime configuration. Values come from Vite env vars (see .env.example).
 *
 * USE_MOCK defaults to true in dev so the app is clickable offline. In
 * production builds it is *forced* to false, regardless of what the env
 * var says — the mock store accepts any password (see api/auth.js), which
 * is fine for demos but would be a critical auth bypass in production.
 */
const env = import.meta.env;

const wantsMock = env.VITE_USE_MOCK !== "false"; // dev default

if (env.PROD && wantsMock) {
  // Loud, visible warning so a misconfigured deploy doesn't silently ship
  // with an open-door auth path. Surfaced in browser devtools.
  console.warn(
    "[config] VITE_USE_MOCK is enabled but this is a production build. " +
      "Forcing USE_MOCK=false to prevent the mock auth bypass."
  );
}

export const USE_MOCK = env.PROD ? false : wantsMock;

export const API = {
  reservation: env.VITE_RESERVATION_API || "http://localhost:3001",
  event: env.VITE_EVENT_API || "http://localhost:3002",
  user: env.VITE_USER_API || "http://localhost:3003",
  admin: env.VITE_ADMIN_API || "http://localhost:3004",
};

/** Artificial latency (ms) for mock responses so loading states are visible. */
export const MOCK_LATENCY = 350;
