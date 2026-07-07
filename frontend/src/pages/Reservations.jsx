import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import PhoneFrame from "../components/PhoneFrame.jsx";
import BottomNav from "../components/BottomNav.jsx";
import LangSelect from "../components/LangSelect.jsx";
import Icon from "../components/Icon.jsx";
import { listMyReservations } from "../api/reservations.js";
import { useAuth } from "../context/AuthContext.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";

/** Map backend status strings to i18n keys. Unknown values fall through. */
const STATUS_KEY = {
  confirmed: "res.status.confirmed",
  cancelled: "res.status.cancelled",
  pending: "res.status.pending",
};

export default function Reservations() {
  const { auth } = useAuth();
  const { t, lang } = useLanguage();
  const [items, setItems] = useState([]);
  const [status, setStatus] = useState("loading");
  // Depend on the token, not the whole auth object — auth identity changes
  // on every token rotation/profile update and would re-fetch needlessly.
  const token = auth?.token;

  useEffect(() => {
    let active = true;

    async function load() {
      try {
        const data = await listMyReservations({ auth, lang });
        if (!active) return;
        setItems(data);
        setStatus("ready");
      } catch {
        if (active) setStatus("error");
      }
    }

    load();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- `auth` is read once per fetch; we re-fetch only when the token/lang changes
  }, [token, lang]);

  return (
    <PhoneFrame footer={<BottomNav />}>
      <div className="screen-head">
        <h1>{t("res.title")}</h1>
        <LangSelect />
      </div>

      {status === "loading" && (
        <div className="state">
          <div className="spinner" />
          {t("res.loading")}
        </div>
      )}

      {status === "ready" && items.length === 0 && (
        <div className="placeholder">
          <span className="placeholder__ic">
            <Icon name="ticket" size={30} />
          </span>
          <h2>{t("res.empty.title")}</h2>
          <p>{t("res.empty.desc")}</p>
          <Link to="/home" className="btn btn--primary btn--sm" style={{ marginTop: 10 }}>
            {t("res.empty.cta")}
          </Link>
        </div>
      )}

      {status === "ready" && items.length > 0 && (
        <ul className="res-list">
          {/* Backend already returns rows ORDER BY created_at DESC
              (reservation-service main.js). Render as-is so newest first. */}
          {items.map((r) => {
            const statusKey = STATUS_KEY[r.status];
            const status = statusKey ? t(statusKey) : r.status;
            const body = (
              <>
                <img src={r.event_image} alt="" />
                <div className="res-item__body">
                  <h3>{r.event_title}</h3>
                  <p>{r.slot_label}</p>
                </div>
                {/* Translate known statuses; show raw value for unknown ones
                    so backend-side new states are still visible. */}
                <span className="res-status">{status}</span>
              </>
            );
            // Tapping a reservation opens its event detail. Only linkable when
            // the backend supplied an event_id; otherwise render a plain row so
            // we never produce a dead /event/undefined link.
            return (
              <li key={r.id}>
                {r.event_id != null ? (
                  <Link
                    to={`/event/${r.event_id}`}
                    className="card res-item res-item--link"
                    aria-label={`${r.event_title} — ${status}`}
                  >
                    {body}
                  </Link>
                ) : (
                  <div className="card res-item">{body}</div>
                )}
              </li>
            );
          })}
        </ul>
      )}
    </PhoneFrame>
  );
}
