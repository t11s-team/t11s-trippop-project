import Icon from "./Icon.jsx";
import { CATEGORIES } from "../mocks/events.js";
import { useLanguage } from "../context/LanguageContext.jsx";

/**
 * Horizontal scroll of category filters with icon tiles.
 *
 * CATEGORIES is imported from mocks but its `labelKey` field (added with i18n)
 * provides the translation key. The `id` and `icon` are stable.
 */
export default function CategoryTabs({ active, onChange }) {
  const { t } = useLanguage();
  return (
    <div className="cats no-scrollbar">
      {CATEGORIES.map((cat) => (
        <button
          key={cat.id}
          type="button"
          className={`cat${active === cat.id ? " cat--active" : ""}`}
          onClick={() => onChange(cat.id)}
          aria-pressed={active === cat.id}
        >
          <span className="cat__ic">
            <Icon name={cat.icon} size={24} />
          </span>
          {t(cat.labelKey)}
        </button>
      ))}
    </div>
  );
}
