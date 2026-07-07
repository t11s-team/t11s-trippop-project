import PhoneFrame from "../components/PhoneFrame.jsx";
import BottomNav from "../components/BottomNav.jsx";
import LangSelect from "../components/LangSelect.jsx";
import Icon from "../components/Icon.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";

/**
 * Shared "coming soon" screen so every bottom-nav tab is reachable.
 * `title` is now expected to be an *i18n key* (e.g. "nav.schedule").
 */
export default function Placeholder({ title, icon = "grid" }) {
  const { t } = useLanguage();
  return (
    <PhoneFrame footer={<BottomNav />}>
      <div className="screen-head">
        <h1>{t(title)}</h1>
        <LangSelect />
      </div>
      <div className="placeholder">
        <span className="placeholder__ic">
          <Icon name={icon} size={30} />
        </span>
        <h2>{t(title)}</h2>
        <p>{t("placeholder.comingSoon")}</p>
      </div>
    </PhoneFrame>
  );
}
