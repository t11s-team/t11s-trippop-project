/**
 * Mock catalogue used in mock-first mode. Shapes mirror what the *fixed*
 * backend should eventually return (see docs/BACKEND_REVIEW.md issue #17:
 * the real GET /events is missing image_url / dates / capacity).
 *
 * Images are local mock SVGs under /mock so the app needs no network.
 */
export const CATEGORIES = [
  { id: "all",        labelKey: "cat.all",        icon: "grid" },
  { id: "popup",      labelKey: "cat.popup",      icon: "bag" },
  { id: "kpop",       labelKey: "cat.kpop",       icon: "music" },
  { id: "exhibition", labelKey: "cat.exhibition", icon: "image" },
  { id: "experience", labelKey: "cat.experience", icon: "star" },
];

export const EVENTS = [
  {
    id: 1,
    category: "popup",
    badge: "POP-UP",
    title: "Fennec Seongsu Pop-up",
    subtitle: "Discover Fennec's latest collections in Seongsu",
    description: "Fennec's signature wallets to the latest bag collection.",
    about:
      "Visit Fennec's newly opened Seongsu pop-up and discover signature wallets, bags, and exclusive collections.",
    image: "/mock/popup-fennec.svg",
    dateRange: "May 6 (Mon) - May 20 (Sun)",
    dateShort: "05.06 (Mon) - 05.20 (Sun)",
    hours: "Everyday, 11:00 - 20:00",
    location: "20-8, Seoulsup 2-gil, Seongdong-gu, Seoul",
    locationShort: "Seoul, South Korea",
    price: "Free Reservation",
    offer: "30% off select",
    map: "/mock/map-seongsu.svg",
    gallery: ["/mock/gallery-1.svg", "/mock/gallery-2.svg", "/mock/gallery-3.svg"],
    slots: [
      { id: 11, slot_datetime: "2026-05-06T11:00:00", remaining_capacity: 12, max_capacity: 30, version: 0 },
      { id: 12, slot_datetime: "2026-05-06T15:00:00", remaining_capacity: 4, max_capacity: 30, version: 0 },
    ],
    limited: true,
    slotsLeft: 12,
  },
  {
    id: 2,
    category: "popup",
    badge: "POP-UP",
    title: "Fennec Hannam Flagship",
    subtitle: "A curated flagship experience in Hannam",
    description: "Fennec's signature additions to the latest bag collection.",
    about:
      "Step into Fennec's Hannam flagship to explore seasonal drops and limited editions in a calm, gallery-like space.",
    image: "/mock/popup-fennec-2.svg",
    dateRange: "May 10 (Sat) - May 31 (Sun)",
    dateShort: "05.10 (Sat) - 05.31 (Sun)",
    hours: "Everyday, 11:00 - 21:00",
    location: "44, Itaewon-ro, Yongsan-gu, Seoul",
    locationShort: "Seoul, South Korea",
    price: "Free Reservation",
    offer: "Gift with purchase",
    map: "/mock/map-seongsu.svg",
    gallery: ["/mock/gallery-2.svg", "/mock/gallery-3.svg", "/mock/gallery-1.svg"],
    slots: [
      { id: 21, slot_datetime: "2026-05-10T12:00:00", remaining_capacity: 24, max_capacity: 40, version: 0 },
    ],
    limited: false,
    slotsLeft: 24,
  },
  {
    id: 3,
    category: "kpop",
    badge: "K-POP",
    title: "K-POP Dance Class",
    subtitle: "Learn the latest choreography with pro dancers",
    description: "Hands-on dance session with professional K-POP instructors.",
    about:
      "Join a high-energy K-POP dance class led by professional choreographers. All levels welcome — no experience needed.",
    image: "/mock/popup-kpop.svg",
    dateRange: "Jun 2 (Tue) - Jun 30 (Tue)",
    dateShort: "06.02 (Tue) - 06.30 (Tue)",
    hours: "Tue & Thu, 18:00 - 20:00",
    location: "Gangnam-daero, Gangnam-gu, Seoul",
    locationShort: "Seoul, South Korea",
    price: "Free Reservation",
    offer: "First class free",
    map: "/mock/map-seongsu.svg",
    gallery: ["/mock/gallery-3.svg", "/mock/gallery-1.svg", "/mock/gallery-2.svg"],
    slots: [
      { id: 31, slot_datetime: "2026-06-02T18:00:00", remaining_capacity: 2, max_capacity: 10, version: 0 },
    ],
    limited: true,
    slotsLeft: 2,
  },
  {
    id: 4,
    category: "exhibition",
    badge: "EXHIBITION",
    title: "Gyeongbokgung Hanbok Experience",
    subtitle: "Traditional hanbok and palace tour",
    description: "Wear a traditional hanbok and explore the royal palace.",
    about:
      "Experience Korean tradition by wearing a hanbok and touring the historic Gyeongbokgung Palace grounds.",
    image: "/mock/popup-hanbok.svg",
    dateRange: "Jun 1 (Sun) - Aug 31 (Sun)",
    dateShort: "06.01 (Sun) - 08.31 (Sun)",
    hours: "Everyday, 09:00 - 18:00",
    location: "161 Sajik-ro, Jongno-gu, Seoul",
    locationShort: "Seoul, South Korea",
    price: "Free Reservation",
    offer: "Photo pack included",
    map: "/mock/map-seongsu.svg",
    gallery: ["/mock/gallery-1.svg", "/mock/gallery-2.svg", "/mock/gallery-3.svg"],
    slots: [
      { id: 41, slot_datetime: "2026-06-01T10:00:00", remaining_capacity: 18, max_capacity: 20, version: 0 },
    ],
    limited: false,
    slotsLeft: 18,
  },
];

export const findEvent = (id) => EVENTS.find((e) => String(e.id) === String(id));
