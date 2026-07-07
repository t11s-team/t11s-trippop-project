import { useEffect, useRef, useState } from "react";
import Icon from "./Icon.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";
import { LANG_LABELS, LANG_SHORT } from "../lib/i18n.js";

/**
 * Language switcher pill — shows the current short code and opens a dropdown
 * with the full language name.
 *
 * UX notes:
 *  - Closes on outside click / Escape.
 *  - The current language is marked aria-current="true".
 *  - Visible label uses the short code (KO/EN/ZH/AR) so the pill stays narrow.
 *  - Each menu item uses its native script (한국어, English, 中文, العربية) so
 *    users find their own language without already knowing the target language.
 */
export default function LangSelect() {
  const { lang, setLang, supported, t } = useLanguage();
  const [open, setOpen] = useState(false);
  const wrapRef = useRef(null);

  // Close on outside click + Escape. One effect, one ref — keeps this tiny.
  useEffect(() => {
    if (!open) return;
    function onDocClick(e) {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setOpen(false);
    }
    function onKey(e) {
      if (e.key === "Escape") setOpen(false);
    }
    document.addEventListener("mousedown", onDocClick);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDocClick);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div className="lang-wrap" ref={wrapRef}>
      <button
        className="lang"
        type="button"
        aria-label={t("lang.change")}
        aria-haspopup="listbox"
        aria-expanded={open}
        onClick={() => setOpen((v) => !v)}
      >
        {LANG_SHORT[lang]}
        <Icon name="chevron-down" size={16} />
      </button>

      {open && (
        <ul className="lang-menu" role="listbox" aria-label={t("lang.change")}>
          {supported.map((code) => (
            <li key={code}>
              <button
                type="button"
                className={`lang-menu__item${code === lang ? " lang-menu__item--active" : ""}`}
                role="option"
                aria-selected={code === lang}
                onClick={() => {
                  setLang(code);
                  setOpen(false);
                }}
              >
                <span className="lang-menu__code">{LANG_SHORT[code]}</span>
                <span className="lang-menu__name">{LANG_LABELS[code]}</span>
              </button>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
