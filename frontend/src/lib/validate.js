/**
 * Validators return errors keyed by field, with values that are *i18n keys*
 * rather than English strings. The component looks them up via t() so the
 * exact same validator works in every language.
 *
 * Pure functions — they never mutate their input.
 */
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export function validateSignIn({ email, password }) {
  const errors = {};
  if (!email?.trim()) errors.email = "validate.email.required";
  else if (!EMAIL_RE.test(email)) errors.email = "validate.email.invalid";
  if (!password) errors.password = "validate.password.required";
  return errors;
}

export function validateSignUp({ name, email, password, confirm }) {
  const errors = {};
  if (!name?.trim()) errors.name = "validate.name.required";
  if (!email?.trim()) errors.email = "validate.email.required";
  else if (!EMAIL_RE.test(email)) errors.email = "validate.email.invalid";
  if (!password) errors.password = "validate.password.required";
  else if (password.length < 8) errors.password = "validate.password.short";
  if (!confirm) errors.confirm = "validate.confirm.required";
  else if (confirm !== password) errors.confirm = "validate.confirm.mismatch";
  return errors;
}

export const hasErrors = (errors) => Object.keys(errors).length > 0;
