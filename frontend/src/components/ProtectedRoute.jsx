import { Navigate, useLocation } from "react-router-dom";
import { useAuth } from "../context/AuthContext.jsx";

/** Redirects unauthenticated users to Sign In, preserving where they wanted to go. */
export default function ProtectedRoute({ children }) {
  const { isAuthed, expired } = useAuth();
  const location = useLocation();
  if (!isAuthed) {
    return (
      <Navigate
        to="/"
        replace
        state={{ from: location.pathname, reason: expired ? "expired" : undefined }}
      />
    );
  }
  return children;
}
