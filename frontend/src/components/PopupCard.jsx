import { Link } from "react-router-dom";
import Icon from "./Icon.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";

/**
 * Event card — vertical rectangle with the image on top and details below.
 * Used inside the horizontally-scrolling .ticket-list carousel on Home.
 *
 * Layout:
 *   [ image ]            ← Available pill (top-left), heart (top-right)
 *   [ POP-UP tag ]
 *   [ title ]
 *   [ 2-line description ]
 *   [ calendar  date ]
 *   [ pin       location ]
 *   ── dashed divider ──
 *   [ N left ]            [ Reserve → ]   ← bottom CTA row
 */
export default function PopupCard({ event }) {
  const { t } = useLanguage();
  const soldOut = event.slotsLeft <= 0;

  return (
    <Link to={`/event/${event.id}`} className="ticket">
      <div className="ticket__stub">
        <img src={event.image} alt={event.title} loading="lazy" draggable={false} />
        <span className={`ticket__avail${soldOut ? " is-soldout" : ""}`}>
          {soldOut ? t("home.empty") : t("home.available")}
        </span>
        <span className="ticket__save" aria-hidden="true">
          <Icon name="heart" size={16} />
        </span>
      </div>

      <div className="ticket__body">
        <span className="ticket__tag">{event.badge}</span>
        <h3 className="ticket__title">{event.title}</h3>
        <p className="ticket__desc">{event.subtitle || event.description}</p>

        <div className="ticket__meta">
          <span className="ticket__meta-row">
            <Icon name="calendar" size={13} />
            <span>{event.dateShort || event.dateRange}</span>
          </span>
          {event.location && (
            <span className="ticket__meta-row">
              <Icon name="map-pin" size={13} />
              <span>{event.location}</span>
            </span>
          )}
        </div>

        <div className="ticket__foot">
          <span className={`ticket__left${soldOut ? " is-soldout" : ""}`}>
            {soldOut ? t("home.empty") : t("home.left", { n: event.slotsLeft })}
          </span>
          <span className={`ticket__cta${soldOut ? " is-soldout" : ""}`}>
            {t("detail.reserve")}
            <Icon name="arrow-right" size={13} />
          </span>
        </div>
      </div>
    </Link>
  );
}
