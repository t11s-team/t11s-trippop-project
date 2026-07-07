import { useRef, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import PhoneFrame from "../components/PhoneFrame.jsx";
import LangSelect from "../components/LangSelect.jsx";
import TextField from "../components/TextField.jsx";
import Icon from "../components/Icon.jsx";
import { useAuth } from "../context/AuthContext.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";
import { validateSignUp, hasErrors } from "../lib/validate.js";

export default function SignUp() {
  const { signUp } = useAuth();
  const { t, lang } = useLanguage();
  const navigate = useNavigate();
  // Used to refocus email when a duplicate-email signup fails — the typical
  // recovery is to fix the email or switch to Sign In, not retype the password.
  const emailRef = useRef(null);

  const [form, setForm] = useState({ name: "", email: "", password: "", confirm: "" });
  const [errors, setErrors] = useState({});
  const [formError, setFormError] = useState("");
  const [submitting, setSubmitting] = useState(false);

  const update = (key) => (value) => setForm((prev) => ({ ...prev, [key]: value }));

  async function handleSubmit(e) {
    e.preventDefault();
    setFormError("");
    const validation = validateSignUp(form);
    setErrors(validation);
    if (hasErrors(validation)) return;

    setSubmitting(true);
    try {
      // Pass the user's current UI language as their preferred `language`.
      // Backend accepts it so future emails / push notifications can match.
      await signUp({
        name: form.name,
        email: form.email,
        password: form.password,
        language: lang,
      });
      navigate("/home", { replace: true });
    } catch (err) {
      setFormError(err.message);
      // Clear the credentials on failure so password managers don't capture
      // the rejected combo, and the user sees a fresh field instead of
      // stale plaintext sitting on screen.
      setForm((prev) => ({ ...prev, password: "", confirm: "" }));
      emailRef.current?.focus();
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <PhoneFrame variant="auth">
      <form className="auth" onSubmit={handleSubmit} noValidate>
        <div className="auth__topbar auth__topbar--back">
          <button
            type="button"
            className="auth__back"
            onClick={() => navigate(-1)}
            aria-label={t("auth.back")}
          >
            <Icon name="arrow-left" size={22} />
          </button>
          {/* SignUp now also exposes the language switcher — many users land
              here first via a deep link and need to change language. */}
          <LangSelect />
        </div>

        <h1 className="auth__title" style={{ fontSize: 30, marginTop: 16 }}>
          {t("auth.title.signup")}
        </h1>
        <p className="auth__subtitle">{t("auth.subtitle.signup")}</p>

        <div className="auth__form">
          <TextField
            icon="user"
            name="name"
            placeholder={t("auth.name.placeholder")}
            autoComplete="name"
            value={form.name}
            onChange={update("name")}
            error={errors.name ? t(errors.name) : undefined}
          />
          <TextField
            icon="mail"
            type="email"
            name="email"
            placeholder={t("auth.email.signup.placeholder")}
            autoComplete="email"
            value={form.email}
            onChange={update("email")}
            error={errors.email ? t(errors.email) : undefined}
            inputRef={emailRef}
          />
          <TextField
            icon="lock"
            type="password"
            name="password"
            placeholder={t("auth.password.signup.placeholder")}
            autoComplete="new-password"
            value={form.password}
            onChange={update("password")}
            error={errors.password ? t(errors.password) : undefined}
          />
          <TextField
            icon="lock"
            type="password"
            name="confirm"
            placeholder={t("auth.password.confirm.placeholder")}
            autoComplete="new-password"
            value={form.confirm}
            onChange={update("confirm")}
            error={errors.confirm ? t(errors.confirm) : undefined}
          />

          {formError && <p className="field-error" role="alert">{formError}</p>}

          <button
            className="btn btn--primary auth__submit"
            type="submit"
            disabled={submitting}
            style={{ marginTop: 20 }}
          >
            {submitting ? t("auth.signup.loading") : t("auth.signup")}
            {!submitting && (
              <span className="btn__end">
                <Icon name="login" size={20} />
              </span>
            )}
          </button>
        </div>

        <p className="auth__foot">
          {t("auth.haveAccount")}
          <Link to="/">{t("auth.signin.link")}</Link>
        </p>
      </form>
    </PhoneFrame>
  );
}
