/** Thin fetch wrapper. Adds JSON + bearer token, normalizes errors. */
const TOKEN_KEY = "trippop.auth";

export function getStoredAuth() {
  try {
    const raw = localStorage.getItem(TOKEN_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function storeAuth(auth) {
  try {
    localStorage.setItem(TOKEN_KEY, JSON.stringify(auth));
  } catch {
    /* Storage unavailable (Safari private mode, quota). The app keeps
       working in-memory; the user will need to re-login on reload. */
  }
}

export function clearAuth() {
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* ignore */
  }
}

/**
 * Hook the AuthProvider registers so the fetch layer can ask it to log out
 * when the server says the token is invalid. Defined here (not in the
 * provider) so every API call goes through the same gate without having to
 * pass the handler down through every function signature.
 */
let onUnauthorized = null;
export function setOnUnauthorized(handler) {
  onUnauthorized = handler;
}

/** A typed error so the UI can show backend messages without leaking internals. */
export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

export async function request(url, { method = "GET", body, headers = {}, token } = {}) {
  let res;
  try {
    res = await fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...headers,
      },
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch {
    // The UI catches ApiError and can call t("error.network") via the i18n key
    // returned in `.code`. Falls back to the English `message` if no i18n.
    const e = new ApiError("Cannot reach the server. Check your connection.", 0);
    e.code = "error.network";
    throw e;
  }

  const text = await res.text();
  const data = text ? safeJson(text) : null;

  if (!res.ok) {
    // 401 = stored token is no longer valid (rotated by another login,
    // expired, or revoked). Drop the auth state once, here, so every screen
    // doesn't have to handle it. Skip when no token was sent — that's a
    // bare login attempt failing, not a session expiry.
    if (res.status === 401 && token && onUnauthorized) onUnauthorized();
    const message = data?.message || data?.error || `Request failed (${res.status})`;
    const apiError = new ApiError(message, res.status);
    // Backend `message` is hardcoded Korean; expose the stable English `error`
    // code so the UI can map it to a localized i18n key (see EventDetail).
    apiError.backendError = data?.error;
    throw apiError;
  }
  return data;
}

function safeJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
}
