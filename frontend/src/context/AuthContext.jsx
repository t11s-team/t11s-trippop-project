import { createContext, useContext, useEffect, useState, useCallback, useMemo } from "react";
import { getStoredAuth, storeAuth, clearAuth, setOnUnauthorized } from "../api/client.js";
import * as authApi from "../api/auth.js";

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  // auth = { token, user } | null
  const [auth, setAuth] = useState(() => getStoredAuth());
  // Flipped to true when the server invalidates our token. ProtectedRoute
  // reads this to show a one-shot "session expired" message after redirect.
  const [expired, setExpired] = useState(false);

  const apply = useCallback((next) => {
    storeAuth(next); // persist
    setAuth(next); // immutable replace
    setExpired(false); // fresh login wipes the stale flag
    return next;
  }, []);

  const signIn = useCallback(
    async (credentials) => apply(await authApi.signIn(credentials)),
    [apply]
  );

  const signUp = useCallback(
    async (details) => apply(await authApi.signUp(details)),
    [apply]
  );

  const signOut = useCallback(() => {
    clearAuth();
    setAuth(null);
  }, []);

  // Register the 401 hook once. When the fetch layer sees an authed request
  // come back 401, it calls this — we drop session state and let
  // ProtectedRoute push the user back to the sign-in screen.
  useEffect(() => {
    setOnUnauthorized(() => {
      clearAuth();
      setAuth(null);
      setExpired(true);
    });
    return () => setOnUnauthorized(null);
  }, []);

  const clearExpired = useCallback(() => setExpired(false), []);

  const value = useMemo(
    () => ({
      auth,
      isAuthed: Boolean(auth?.token),
      expired,
      clearExpired,
      signIn,
      signUp,
      signOut,
    }),
    [auth, expired, clearExpired, signIn, signUp, signOut]
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components -- hook colocated with its provider
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within <AuthProvider>");
  return ctx;
}
