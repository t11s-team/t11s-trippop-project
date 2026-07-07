import { NavLink } from "react-router-dom";
import Icon from "./Icon.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";

const TABS = [
  { to: "/home",         labelKey: "nav.home",         icon: "home" },
  { to: "/reservations", labelKey: "nav.reservations", icon: "list" },
  { to: "/schedule",     labelKey: "nav.schedule",     icon: "calendar" },
  { to: "/saved",        labelKey: "nav.saved",        icon: "heart" },
  { to: "/me",           labelKey: "nav.me",           icon: "user" },
];

export default function BottomNav() {
  const { t } = useLanguage();
  return (
    <nav className="bottomnav" aria-label={t("nav.primary")}>
      {TABS.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className={({ isActive }) =>
            `bottomnav__item${isActive ? " bottomnav__item--active" : ""}`
          }
        >
          <Icon name={tab.icon} size={22} />
          <span>{t(tab.labelKey)}</span>
        </NavLink>
      ))}
    </nav>
  );
}
