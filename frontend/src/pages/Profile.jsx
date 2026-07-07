import { useState } from "react";
import { useNavigate } from "react-router-dom";
import PhoneFrame from "../components/PhoneFrame.jsx";
import BottomNav from "../components/BottomNav.jsx";
import LangSelect from "../components/LangSelect.jsx";
import Icon from "../components/Icon.jsx";
import { useAuth } from "../context/AuthContext.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";
import { LANG_LABELS } from "../lib/i18n.js";

export default function Profile() {
  const { auth, signOut } = useAuth();
  const { t, lang, setLang, supported } = useLanguage();
  const navigate = useNavigate();
  const user = auth?.user;
  const [showLang, setShowLang] = useState(false);

  function handleSignOut() {
    signOut();
    navigate("/", { replace: true });
  }

  // Menu rows defined in render so they pick up the latest `lang`.
  // `onClick` and `to` are mutually exclusive — keep it simple.
  const rows = [
    { icon: "ticket", label: t("profile.menu.reservations"), to: "/reservations" },
    { icon: "heart", label: t("profile.menu.saved"), to: "/saved" },
    {
      icon: "globe",
      label: t("profile.menu.language"),
      value: LANG_LABELS[lang],
      onClick: () => setShowLang(true),
    },
    { icon: "shield", label: t("profile.menu.security") },
    { icon: "bell", label: t("profile.menu.notifications") },
  ];

  return (
    <PhoneFrame footer={<BottomNav />}>
      <div className="screen-head">
        <h1>{t("profile.title")}</h1>
        <LangSelect />
      </div>

      <div style={{ padding: "24px 20px", display: "flex", alignItems: "center", gap: 16 }}>
        <span className="placeholder__ic" style={{ width: 64, height: 64 }}>
          <Icon name="user" size={30} />
        </span>
        <div style={{ textAlign: "start" }}>
          <h2 style={{ fontSize: 20 }}>{user?.name || t("profile.guest")}</h2>
          <p style={{ color: "var(--ink-400)" }}>{user?.email}</p>
        </div>
      </div>

      <hr className="divider" />

      <ul style={{ padding: "8px 20px", listStyle: "none", margin: 0 }}>
        {rows.map((row) => {
          const interactive = Boolean(row.to || row.onClick);
          const handleClick = () => (row.to ? navigate(row.to) : row.onClick?.());
          const rowStyle = {
            display: "flex",
            alignItems: "center",
            gap: 14,
            width: "100%",
            padding: "16px 4px",
            borderBottom: "1px solid var(--line)",
            background: "transparent",
            border: 0,
            borderBottomWidth: 1,
            borderBottomStyle: "solid",
            borderBottomColor: "var(--line)",
            font: "inherit",
            textAlign: "start",
            color: "inherit",
            cursor: interactive ? "pointer" : "default",
          };
          const content = (
            <>
              <span style={{ color: "var(--brand-700)" }}>
                <Icon name={row.icon} size={20} />
              </span>
              <span style={{ flex: 1, color: "var(--ink-900)", fontWeight: 600 }}>
                {row.label}
              </span>
              {row.value && (
                <span style={{ color: "var(--ink-400)", fontSize: 14, marginInlineEnd: 6 }}>
                  {row.value}
                </span>
              )}
              {/* Chevron implies "tap to navigate" — only show it on rows that
                  actually do something, so static rows don't look broken. */}
              {interactive && <Icon name="chevron-right" size={18} />}
            </>
          );
          return (
            <li key={row.label}>
              {interactive ? (
                // <button> for keyboard focus + screen-reader announcements.
                // Non-interactive rows render as a plain div instead.
                <button type="button" onClick={handleClick} style={rowStyle}>
                  {content}
                </button>
              ) : (
                <div style={rowStyle}>{content}</div>
              )}
            </li>
          );
        })}
      </ul>

      <div style={{ padding: "16px 20px" }}>
        <button className="btn btn--ghost" type="button" onClick={handleSignOut}>
          {t("profile.signout")}
        </button>
      </div>

      {/* Bottom-sheet style language picker inside Profile (alternative path to
          the header LangSelect; some users miss the pill at the top). */}
      {showLang && (
        <div className="sheet-overlay" onClick={() => setShowLang(false)}>
          <div
            className="sheet"
            role="dialog"
            aria-modal="true"
            aria-label={t("profile.menu.language")}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="sheet__handle" />
            <div className="sheet__header">
              <h2 style={{ fontSize: 22 }}>{t("profile.menu.language")}</h2>
              <button
                className="field__toggle"
                onClick={() => setShowLang(false)}
                aria-label={t("filter.close")}
              >
                <Icon name="x" size={22} />
              </button>
            </div>
            <div className="sheet__body no-scrollbar">
              {supported.map((code) => (
                <button
                  key={code}
                  type="button"
                  className={`lang-menu__item${code === lang ? " lang-menu__item--active" : ""}`}
                  style={{ width: "100%" }}
                  onClick={() => {
                    setLang(code);
                    setShowLang(false);
                  }}
                >
                  <span className="lang-menu__name">{LANG_LABELS[code]}</span>
                  {code === lang && <Icon name="check" size={18} />}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}
    </PhoneFrame>
  );
}
