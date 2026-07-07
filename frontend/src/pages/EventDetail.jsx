import { useEffect, useMemo, useRef, useState } from "react";
import { useParams, useNavigate } from "react-router-dom";
import PhoneFrame from "../components/PhoneFrame.jsx";
import LangSelect from "../components/LangSelect.jsx";
import Icon from "../components/Icon.jsx";
import Toast from "../components/Toast.jsx";
import { getEvent } from "../api/events.js";
import { reserve } from "../api/reservations.js";
import { useAuth } from "../context/AuthContext.jsx";
import { useLanguage } from "../context/LanguageContext.jsx";
import { formatDateLabel, formatTime } from "../lib/format.js";

// The reservation-service returns hardcoded Korean `message` strings, so we
// never display them directly. Instead we map its stable English `error` code
// to a localized i18n key so the toast follows the current UI language.
const RESERVE_ERROR_KEYS = {
  "Already reserved": "error.reserve.duplicate",
  "Duplicate request": "error.reserve.duplicate",
  Duplicate: "error.reserve.duplicate",
  "Sold out": "error.reserve.soldout",
  "Version conflict": "error.reserve.retry",
};

export default function EventDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const { auth } = useAuth();
  const { t, lang } = useLanguage();

  const [event, setEvent] = useState(null);
  const [status, setStatus] = useState("loading"); // loading | ready | error
  const [saved, setSaved] = useState(false);
  const [reserving, setReserving] = useState(false);
  const [reserved, setReserved] = useState(false);
  const [toast, setToast] = useState(null); // { message, type }
  // The user must explicitly pick a slot before reserving. We do NOT auto-
  // fallback to "first available" anymore — that was the source of the bug
  // where rapid clicks silently jumped from a sold-out slot to the next date.
  const [selectedSlotId, setSelectedSlotId] = useState(null);
  // Holds the post-reservation auto-navigate timer so unmount cancels it.
  const navTimerRef = useRef(null);

  // Clear any pending nav timer on unmount so we don't navigate from a
  // component that's already gone (React 18+ would warn).
  useEffect(() => () => {
    if (navTimerRef.current) clearTimeout(navTimerRef.current);
  }, []);

  // Re-fetch on id or language change.
  useEffect(() => {
    let active = true;

    async function load() {
      setStatus("loading");
      try {
        const data = await getEvent(id, { lang });
        if (!active) return;
        setEvent(data);
        // Preselect the first slot only if it has capacity. If it's sold
        // out we leave selection blank so the user has to consciously
        // choose another date — no surprise fallback.
        const first = data.slots?.[0];
        if (first && first.remaining_capacity > 0) {
          setSelectedSlotId(first.id);
        } else {
          setSelectedSlotId(null);
        }
        setStatus("ready");
      } catch {
        if (active) setStatus("error");
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [id, lang]);

  const selectedSlot = useMemo(
    () => event?.slots?.find((s) => s.id === selectedSlotId) ?? null,
    [event, selectedSlotId]
  );

  async function handleReserve() {
    if (!event?.slots?.length) {
      setToast({ message: t("detail.noSlots"), type: "error" });
      return;
    }
    // No slot picked → tell the user. Do NOT silently grab any slot.
    if (!selectedSlot) {
      setToast({ message: t("detail.selectSlot.required"), type: "error" });
      return;
    }
    // Picked slot is sold out — refuse. The button should already be
    // disabled in this state, but guard anyway.
    if (selectedSlot.remaining_capacity <= 0) {
      setToast({ message: t("detail.slot.soldout"), type: "error" });
      return;
    }

    const enriched = {
      ...selectedSlot,
      event_id: event.id,
      event_title: event.title,
      event_image: event.image,
      label: `${formatDateLabel(selectedSlot.slot_datetime, lang)} · ${formatTime(selectedSlot.slot_datetime, lang)}`,
    };

    setReserving(true);
    try {
      const result = await reserve({ auth, slot: enriched });
      setReserved(true);
      setToast({
        message: result.idempotent ? t("detail.alreadyReserved") : t("detail.confirmed"),
        type: "success",
      });
      navTimerRef.current = setTimeout(() => navigate("/reservations"), 1400);
    } catch (err) {
      // Prefer a localized message: reservation error code → i18n key,
      // then a network/i18n code (e.g. error.network), else a generic fallback.
      const key =
        RESERVE_ERROR_KEYS[err.backendError] || err.code || "error.reserve.failed";
      setToast({ message: t(key), type: "error" });
    } finally {
      setReserving(false);
    }
  }

  if (status === "loading") {
    return (
      <PhoneFrame>
        <div className="state">
          <div className="spinner" />
          {t("detail.loading")}
        </div>
      </PhoneFrame>
    );
  }
  if (status === "error" || !event) {
    return (
      <PhoneFrame>
        <div className="state">
          {t("detail.error")}
          <div style={{ marginTop: 16 }}>
            <button className="btn btn--ghost btn--sm" onClick={() => navigate("/home")}>
              {t("detail.backHome")}
            </button>
          </div>
        </div>
      </PhoneFrame>
    );
  }

  const infoRows = [
    { icon: "calendar", text: event.dateRange },
    { icon: "clock", text: event.hours },
    { icon: "map-pin", text: event.location },
  ];

  const reserveDisabled = reserving || reserved || !selectedSlot || selectedSlot.remaining_capacity <= 0;

  return (
    <PhoneFrame>
      <div className="detail__hero">
        <img src={event.image} alt={event.title} />
        <div className="detail__hero-top">
          <button className="icon-btn" onClick={() => navigate(-1)} aria-label={t("detail.back")}>
            <Icon name="arrow-left" size={20} />
          </button>
          <div className="detail__hero-actions">
            <LangSelect />
            <button
              className="icon-btn"
              onClick={() => setSaved((s) => !s)}
              aria-label={saved ? t("detail.unsave") : t("detail.save")}
              style={saved ? { color: "var(--brand-600)" } : undefined}
            >
              <Icon name="heart" size={20} />
            </button>
          </div>
        </div>
      </div>

      <div className="detail__sheet">
        <span className="badge badge--popup">{event.badge}</span>
        <h1 className="detail__title">{event.title}</h1>
        <p className="detail__subtitle">{event.subtitle}</p>

        <div>
          {infoRows.map((row) => (
            <div className="info-row" key={row.icon}>
              <span className="info-row__ic">
                <Icon name={row.icon} size={20} />
              </span>
              <span className="info-row__text">{row.text}</span>
            </div>
          ))}
        </div>

        {/* ===== Slot picker =====
            Shown only when the event has 2+ slots. With a single slot, the
            picker would just be a redundant card — we still preselect it
            in state so the reserve flow works the same. */}
        {event.slots && event.slots.length > 1 && (
          <div className="detail__section">
            <h3>{t("detail.selectSlot")}</h3>
            <div className="slot-list">
              {event.slots.map((slot) => {
                const isOn = slot.id === selectedSlotId;
                const isSoldout = slot.remaining_capacity <= 0;
                return (
                  <button
                    type="button"
                    key={slot.id}
                    className={`slot${isOn ? " slot--on" : ""}${isSoldout ? " slot--soldout" : ""}`}
                    onClick={() => !isSoldout && setSelectedSlotId(slot.id)}
                    disabled={isSoldout}
                  >
                    <span className="slot__when">
                      <span className="slot__date">{formatDateLabel(slot.slot_datetime, lang)}</span>
                      <span className="slot__time">{formatTime(slot.slot_datetime, lang)}</span>
                    </span>
                    <span className={`slot__cap${isSoldout ? " is-soldout" : ""}`}>
                      {isSoldout
                        ? t("detail.slot.soldout")
                        : t("home.left", { n: slot.remaining_capacity })}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Reservation CTA — standalone, no price/offer clutter.
            The button is disabled until a valid (in-stock) slot is chosen. */}
        <div className="detail__section detail__reserve">
          <button
            className="btn btn--primary detail__reserve-btn"
            type="button"
            onClick={handleReserve}
            disabled={reserveDisabled}
          >
            {reserved
              ? t("detail.reserved")
              : reserving
              ? t("detail.reserving")
              : t("detail.reserve")}
            {!reserved && !reserving && <Icon name="arrow-right" size={20} />}
          </button>
          {selectedSlot && selectedSlot.remaining_capacity > 0 && (
            <p className="detail__reserve-note">
              {selectedSlot.label
                ? selectedSlot.label
                : `${formatDateLabel(selectedSlot.slot_datetime, lang)} · ${formatTime(selectedSlot.slot_datetime, lang)}`}
            </p>
          )}
        </div>

        <div className="detail__section">
          <h3>{t("detail.location")}</h3>
          <div className="map__foot">
            <div className="map__addr">
              <h4>{event.title}</h4>
              <p>{event.location}</p>
            </div>
            <button
              className="btn btn--ghost btn--sm"
              type="button"
              onClick={() =>
                window.open(
                  `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                    event.location || event.title
                  )}`,
                  "_blank",
                  "noopener,noreferrer"
                )
              }
            >
              {t("detail.viewMap")}
            </button>
          </div>
        </div>

        {/* 이벤트 상세 — 서술 본문(줄바꿈 보존) + 끝부분에 _main 이미지 */}
        {event.description && (
          <div className="detail__section">
            <h3>{t("detail.eventDetails")}</h3>
            <p className="detail__about-text">{event.description}</p>
            <img
              className="detail__main"
              src={event.mainImage || event.image}
              alt={event.title}
              loading="lazy"
            />
          </div>
        )}

        <div style={{ height: 28 }} />
      </div>

      <Toast
        message={toast?.message}
        type={toast?.type}
        onDone={() => setToast(null)}
      />
    </PhoneFrame>
  );
}
