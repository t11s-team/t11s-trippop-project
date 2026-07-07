import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import PhoneFrame from "../components/PhoneFrame.jsx";
import BottomNav from "../components/BottomNav.jsx";
import LangSelect from "../components/LangSelect.jsx";
import Icon from "../components/Icon.jsx";
import PromoBanner from "../components/PromoBanner.jsx";
import CategoryTabs from "../components/CategoryTabs.jsx";
import PopupCard from "../components/PopupCard.jsx";
import FilterModal from "../components/FilterModal.jsx";
import { listEvents } from "../api/events.js";
import { useLanguage } from "../context/LanguageContext.jsx";
import useDragScroll from "../hooks/useDragScroll.js";

// Fixed promo deadline (~02:45:30 like the mockup), computed once per mount.
const PROMO_DEADLINE = Date.now() + ((2 * 60 + 45) * 60 + 30) * 1000;

export default function Home() {
  const navigate = useNavigate();
  const { t, lang } = useLanguage();
  const [events, setEvents] = useState([]);
  const [status, setStatus] = useState("loading"); // loading | ready | error
  const [category, setCategory] = useState("all");
  const [query, setQuery] = useState("");
  const [showFilter, setShowFilter] = useState(false);
  const [filters, setFilters] = useState(null);

  // Mouse drag scroll for the card carousel (desktop + mobile both work).
  const drag = useDragScroll();

  useEffect(() => {
    let active = true;

    async function load() {
      setStatus("loading");
      try {
        const data = await listEvents({ lang });
        if (!active) return;
        setEvents(data);
        setStatus("ready");
      } catch {
        if (active) setStatus("error");
      }
    }

    load();
    return () => {
      active = false;
    };
  }, [lang]);

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    return events.filter((e) => {
      if (category !== "all" && e.category !== category) return false;
      if (q) {
        const haystack = `${e.title || ""} ${e.description || ""}`.toLowerCase();
        if (!haystack.includes(q)) return false;
      }
      if (filters?.availableNow && e.slotsLeft <= 0) return false;
      if (filters?.limitedOnly && !e.limited) return false;
      return true;
    });
  }, [events, category, query, filters]);

  // The promo banner is tied to a real, featured event (Gyeongbokgung, id 4)
  // instead of a hard-coded "12 left". We use its actual remaining capacity
  // and link straight to its detail page. Falls back to the first event if
  // id 4 isn't present (e.g. a different catalogue from the real backend).
  const featured = useMemo(
    () => events.find((e) => String(e.id) === "4") ?? events[0],
    [events]
  );

  return (
    <PhoneFrame footer={<BottomNav />}>
      <header className="home__header">
        <span className="home__brand">
          Trip<span className="pop">Pop</span>
        </span>
        <div className="home__header-right">
          <LangSelect />
          <Icon name="bell" size={22} />
        </div>
      </header>

      <div className="home__hero">
        <div className="home__hero-bg" aria-hidden="true" />
        <div className="home__intro">
          <h1>{t("home.title")}</h1>
          <p>{t("home.subtitle")}</p>
        </div>
      </div>

      {featured && (
        <PromoBanner
          deadline={PROMO_DEADLINE}
          slotsLeft={featured.slotsLeft}
          onReserve={() => navigate(`/event/${featured.id}`)}
        />
      )}

      <div className="searchbar">
        <div className="searchbar__input">
          <Icon name="search" size={18} />
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t("home.search.placeholder")}
            aria-label={t("home.search.aria")}
          />
        </div>
        <button
          className="searchbar__filter"
          type="button"
          onClick={() => setShowFilter(true)}
        >
          <Icon name="filter" size={18} /> {t("home.filter")}
        </button>
      </div>

      <CategoryTabs active={category} onChange={setCategory} />

      <div className="section-head">
        <h2>
          <Icon name="flame" size={20} style={{ color: "var(--brand-600)" }} />{" "}
          {t("home.hot")}
        </h2>
        <button
          className="section-head-link"
          type="button"
          onClick={() => setCategory("all")}
          style={{ color: "var(--brand-700)", fontWeight: 700, fontSize: 13 }}
        >
          {t("home.seeAll")}
        </button>
      </div>

      {status === "loading" && (
        <div className="state">
          <div className="spinner" />
          {t("home.loading")}
        </div>
      )}
      {status === "error" && (
        <div className="state">{t("home.error")}</div>
      )}
      {status === "ready" && visible.length === 0 && (
        <div className="state">{t("home.empty")}</div>
      )}
      {status === "ready" && visible.length > 0 && (
        /* drag.containerProps spreads ref + mouse handlers + click-capture
           (cancels nav after a drag) + dragstart blocker + cursor.
           Touch users get native scroll for free via overflow-x: auto. */
        <div className="ticket-list" {...drag.containerProps}>
          {visible.map((event) => (
            <PopupCard key={event.id} event={event} />
          ))}
        </div>
      )}

      <div style={{ height: 12 }} />

      {showFilter && (
        <FilterModal
          initial={filters ?? undefined}
          onClose={() => setShowFilter(false)}
          onApply={(next) => {
            setFilters(next);
            setShowFilter(false);
          }}
        />
      )}
    </PhoneFrame>
  );
}
