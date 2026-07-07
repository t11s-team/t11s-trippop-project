import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { AuthProvider } from "./context/AuthContext.jsx";
import ProtectedRoute from "./components/ProtectedRoute.jsx";
import SignIn from "./pages/SignIn.jsx";
import SignUp from "./pages/SignUp.jsx";
import Home from "./pages/Home.jsx";
import EventDetail from "./pages/EventDetail.jsx";
import Reservations from "./pages/Reservations.jsx";
import Profile from "./pages/Profile.jsx";
import Placeholder from "./pages/Placeholder.jsx";

/** Wraps a protected screen with the auth guard. */
const guard = (element) => <ProtectedRoute>{element}</ProtectedRoute>;

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Public */}
          <Route path="/" element={<SignIn />} />
          <Route path="/signup" element={<SignUp />} />

          {/* Protected */}
          <Route path="/home" element={guard(<Home />)} />
          <Route path="/event/:id" element={guard(<EventDetail />)} />
          <Route path="/reservations" element={guard(<Reservations />)} />
          <Route path="/me" element={guard(<Profile />)} />
          {/* Placeholder receives an i18n key (not a literal title) so it
              re-renders correctly on language change. */}
          <Route
            path="/schedule"
            element={guard(<Placeholder title="nav.schedule" icon="calendar" />)}
          />
          <Route
            path="/saved"
            element={guard(<Placeholder title="nav.saved" icon="heart" />)}
          />

          {/* Fallback */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
