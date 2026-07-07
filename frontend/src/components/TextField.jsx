import { useState } from "react";
import Icon from "./Icon.jsx";

/**
 * Icon + input row used on the auth screens. Password fields get a
 * show/hide toggle. Controlled component — value/onChange owned by the parent.
 *
 * `inputRef` lets the parent focus the underlying <input> (e.g. SignUp
 * refocuses the email field after a duplicate-email signup error).
 */
export default function TextField({
  icon,
  type = "text",
  value,
  onChange,
  placeholder,
  error,
  autoComplete,
  name,
  inputRef,
}) {
  const [reveal, setReveal] = useState(false);
  const isPassword = type === "password";
  const inputType = isPassword && reveal ? "text" : type;

  return (
    <div>
      <div className={`field${error ? " field--error" : ""}`}>
        {icon && (
          <span className="field__icon">
            <Icon name={icon} size={20} />
          </span>
        )}
        <input
          ref={inputRef}
          className="field__input"
          type={inputType}
          name={name}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          autoComplete={autoComplete}
          aria-invalid={Boolean(error)}
        />
        {isPassword && (
          <button
            type="button"
            className="field__toggle"
            onClick={() => setReveal((r) => !r)}
            aria-label={reveal ? "Hide password" : "Show password"}
          >
            <Icon name={reveal ? "eye-off" : "eye"} size={20} />
          </button>
        )}
      </div>
      {error && <p className="field-error">{error}</p>}
    </div>
  );
}
