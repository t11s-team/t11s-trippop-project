import { useEffect, useState } from "react";
import { Link, useNavigate, useLocation } from "react-router-dom";
import PhoneFrame from "../components/PhoneFrame.jsx";
import LangSelect from "../components/LangSelect.jsx";
import TextField from "../components/TextField.jsx";
import Icon from "../components/Icon.jsx";
import { useAuth } from "../context/AuthContext.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";
import { validateSignIn, hasErrors } from "../lib/validate.js";

export default function SignIn() {
  const { signIn, expired, clearExpired } = useAuth();
  const { t } = useLanguage();
  const navigate = useNavigate();
  const location = useLocation();
  const redirectTo = location.state?.from || "/home";
  const sessionExpired = expired || location.state?.reason === "expired";

  const [form, setForm] = useState({ email: "", password: "" });
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  // Clear the "expired" flag once the user interacts with the form, so the
  // banner doesn't reappear after a successful re-login round trip.
  useEffect(() => {
    if (!sessionExpired) return;
    if (form.email || form.password) clearExpired();
  }, [form.email, form.password, sessionExpired, clearExpired]);

  const update = (key) => (value) => setForm((prev) => ({ ...prev, [key]: value }));

  async function handleSubmit(e) {
    e.preventDefault();
    setFormError("");
    const validation = validateSignIn(form);
    setErrors(validation);
    if (hasErrors(validation)) return;

    setSubmitting(true);
    try {
      await signIn(form);
      navigate(redirectTo, { replace: true });
    } catch (err) {
      setFormError(err.message);
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <PhoneFrame variant="auth">
      <form className="auth" onSubmit={handleSubmit} noValidate>
        <div className="auth__topbar">
          <LangSelect />
        </div>

        {/* Brand name "TripPop" stays untranslated — it's the product name. */}
        <h1 className="auth__logo">
          Trip<span className="pop">Pop</span>
        </h1>
        <h2 className="auth__title">{t("auth.title.signin")}</h2>
        <p className="auth__subtitle">{t("auth.subtitle.signin")}</p>

        {sessionExpired && (
          <p className="field-error" role="alert" style={{ marginTop: 8 }}>
            {t("error.sessionExpired")}
          </p>
        )}

        <div className="auth__form">
          <TextField
            icon="mail"
            type="email"
            name="email"
            placeholder={t("auth.email.placeholder")}
            autoComplete="email"
            value={form.email}
            onChange={update("email")}
            error={errors.email ? t(errors.email) : undefined}
          />
          <TextField
            icon="lock"
            type="password"
            name="password"
            placeholder={t("auth.password.placeholder")}
            autoComplete="current-password"
            value={form.password}
            onChange={update("password")}
            error={errors.password ? t(errors.password) : undefined}
          />
          {/* "Forgot Password?" routes nowhere yet — keep as a plain span until
              the reset flow is implemented. Avoids deadlink UX bugs. */}
          <span className="auth__forgot" aria-disabled="true">
            {t("auth.forgot")}
          </span>

          {formError && <p className="field-error" role="alert">{formError}</p>}

          <button className="btn btn--primary auth__submit" type="submit" disabled={submitting}>
            {submitting ? t("auth.signin.loading") : t("auth.signin")}
            {!submitting && (
              <span className="btn__end">
                <Icon name="login" size={20} />
              </span>
            )}
          </button>
        </div>

        <div className="auth__trust">
          <span className="auth__trust-ic">
            <Icon name="shield" size={18} />
          </span>
          {t("auth.trust.noPhone")}
        </div>

        <p className="auth__foot">
          {t("auth.noAccount")}
          <Link to="/signup">{t("auth.signup.link")}</Link>
        </p>
      </form>
    </PhoneFrame>
  );
}
