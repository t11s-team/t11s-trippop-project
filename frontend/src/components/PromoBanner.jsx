import Icon from "./Icon.jsx";
import { useCountdown } from "../hooks/useCountdown.js";
import { formatCountdown } from "../lib/format.js";
import { useLanguage } from "../context/LanguageContext.jsx";

/**
 * Green promo banner: trust tag, headline, "LIMITED SLOTS" ribbon,
 * live countdown, and a Reserve CTA.
 */
export default function PromoBanner({ deadline, slotsLeft = 12, onReserve }) {
  const { t } = useLanguage();
  const remaining = useCountdown(deadline);

  return (
    <section className="promo">
      <span className="promo__limited">{t("promo.limited")}</span>
      <span className="badge badge--soft promo__tag">
        <Icon name="shield" size={14} /> {t("promo.noPhone")}
      </span>
      <h3 className="promo__title">{t("promo.title")}</h3>
      <div className="promo__row">
        <span className="promo__count">
          <Icon name="clock" size={16} /> {t("promo.only", { n: slotsLeft })} ·{" "}
          <span className="promo__time">{formatCountdown(remaining)}</span>
        </span>
        <button className="btn btn--primary btn--sm" type="button" onClick={onReserve}>
          {t("promo.reserve")}
        </button>
      </div>
    </section>
  );
}
