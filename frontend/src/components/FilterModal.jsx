import { useState } from "react";
import Icon from "./Icon.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";

/**
 * Filter options now use a stable `id` for state and a `labelKey` for display.
 * The chip's text comes from t(labelKey) at render time so it switches with
 * language without restructuring the option list.
 */
const WHEN_OPTIONS = [
  { id: "today", labelKey: "filter.when.today" },
  { id: "tomorrow", labelKey: "filter.when.tomorrow" },
  { id: "thisWeek", labelKey: "filter.when.thisWeek" },
];

const THEMES = [
  { id: "kpop",       labelKey: "filter.theme.kpop",       icon: "star" },
  { id: "brand",      labelKey: "filter.theme.brand",      icon: "tag" },
  { id: "art",        labelKey: "filter.theme.art",        icon: "palette" },
  { id: "photobooth", labelKey: "filter.theme.photobooth", icon: "camera" },
  { id: "characters", labelKey: "filter.theme.characters", icon: "smile" },
];

const EMPTY = { when: "tomorrow", themes: [], availableNow: true, limitedOnly: true };

/**
 * Bottom-sheet filter. Self-contained local state; commits to the parent only
 * on "Apply Filters" so cancelling discards changes.
 */
export default function FilterModal({ initial = EMPTY, onApply, onClose }) {
  const { t } = useLanguage();
  const [when, setWhen] = useState(initial.when);
  const [themes, setThemes] = useState(initial.themes);
  const [availableNow, setAvailableNow] = useState(initial.availableNow);
  const [limitedOnly, setLimitedOnly] = useState(initial.limitedOnly);

  // Immutable toggle helper for the theme chip set.
  const toggleTheme = (id) =>
    setThemes((prev) => (prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id]));

  const reset = () => {
    setWhen(EMPTY.when);
    setThemes(EMPTY.themes);
    setAvailableNow(EMPTY.availableNow);
    setLimitedOnly(EMPTY.limitedOnly);
  };

  return (
    <div className="sheet-overlay" onClick={onClose}>
      <div
        className="sheet"
        role="dialog"
        aria-modal="true"
        aria-label={t("filter.title")}
        onClick={(e) => e.stopPropagation()}
      >
        <div className="sheet__handle" />
        <div className="sheet__header">
          <h2 style={{ fontSize: 22 }}>{t("filter.title")}</h2>
          <button className="field__toggle" onClick={onClose} aria-label={t("filter.close")}>
            <Icon name="x" size={22} />
          </button>
        </div>

        <div className="sheet__body no-scrollbar">
          {/* When */}
          <div className="filter__group">
            <h3>{t("filter.when")}</h3>
            <div className="filter__row">
              {WHEN_OPTIONS.map((opt) => (
                <button
                  key={opt.id}
                  type="button"
                  className={`chip${when === opt.id ? " chip--active" : ""}`}
                  onClick={() => setWhen(opt.id)}
                >
                  {t(opt.labelKey)}
                </button>
              ))}
            </div>
            <button type="button" className="chip filter__date">
              <Icon name="calendar" size={16} /> {t("filter.pickDate")}
              <Icon name="chevron-right" size={16} />
            </button>
          </div>

          {/* Location */}
          <div className="filter__group">
            <h3>{t("filter.location")}</h3>
            <div className="filter__loc">
              <span className="filter__loc-ic">
                <Icon name="map-pin" size={20} />
              </span>
              <div style={{ flex: 1, textAlign: "start" }}>
                <h4>{t("filter.location.seoul")}</h4>
                <p>{t("filter.location.current")}</p>
              </div>
              <Icon name="chevron-right" size={18} />
            </div>
            <button type="button" className="filter__use-loc">
              <Icon name="crosshair" size={15} /> {t("filter.useLocation")}
            </button>
          </div>

          {/* Themes */}
          <div className="filter__group">
            <h3>
              {t("filter.themes")} <span className="opt">{t("filter.themes.optional")}</span>
            </h3>
            <div className="filter__row">
              {THEMES.map((theme) => (
                <button
                  key={theme.id}
                  type="button"
                  className={`chip chip--theme${themes.includes(theme.id) ? " chip--on" : ""}`}
                  onClick={() => toggleTheme(theme.id)}
                >
                  <Icon name={theme.icon} size={15} /> {t(theme.labelKey)}
                </button>
              ))}
            </div>
          </div>

          {/* Availability */}
          <div className="filter__group">
            <h3>{t("filter.availability")}</h3>
            <button
              type="button"
              className="check-row"
              style={{ width: "100%" }}
              onClick={() => setAvailableNow((v) => !v)}
            >
              <span className={`check-box${availableNow ? " check-box--on" : ""}`}>
                {availableNow && <Icon name="check" size={16} />}
              </span>
              <div style={{ textAlign: "start" }}>
                <h4>{t("filter.availableNow")}</h4>
                <p>{t("filter.availableNow.desc")}</p>
              </div>
            </button>
            <button
              type="button"
              className="check-row"
              style={{ width: "100%" }}
              onClick={() => setLimitedOnly((v) => !v)}
            >
              <span className={`check-box${limitedOnly ? " check-box--on" : ""}`}>
                {limitedOnly && <Icon name="check" size={16} />}
              </span>
              <div style={{ textAlign: "start" }}>
                <h4>{t("filter.limited")}</h4>
                <p>{t("filter.limited.desc")}</p>
              </div>
            </button>
          </div>
        </div>

        <div className="sheet__footer">
          <button className="btn btn--ghost" type="button" onClick={reset}>
            {t("filter.reset")}
          </button>
          <button
            className="btn btn--primary"
            type="button"
            onClick={() => onApply({ when, themes, availableNow, limitedOnly })}
          >
            {t("filter.apply")}
          </button>
        </div>
      </div>
    </div>
  );
}
