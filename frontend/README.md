# TripPop — Frontend (Mobile UI)

React + Vite implementation of the TripPop mobile mockups: a K-culture pop-up /
exhibition discovery and reservation app.

## Screens

| Route | Screen | Mockup |
|-------|--------|--------|
| `/` | Sign In | `Sign in.png` |
| `/signup` | Sign Up | `Sign up.png` |
| `/home` | Home (browse + filter) | `Home / Mobile v2.png` |
| `/event/:id` | Event Detail (+ reserve) | `Event Details.jpg` |
| (sheet) | Filter | `Filter.png` |
| `/reservations`, `/me`, `/schedule`, `/saved` | Bottom-nav tabs | — |

## Run it

```bash
npm install
npm run dev      # http://localhost:5173  (use a mobile viewport)
```

The app runs **mock-first** (`VITE_USE_MOCK=true`) so the whole flow works
offline. Demo login: `emma@test.com` + any password.

See **[`../docs/LOCAL_TESTING_GUIDE.md`](../docs/LOCAL_TESTING_GUIDE.md)** for the
full walkthrough and **[`../docs/BACKEND_REVIEW.md`](../docs/BACKEND_REVIEW.md)**
for the backend mismatch / security / error findings (why mock mode exists and
how to switch to the real services).

## Scripts

- `npm run dev` — dev server with HMR
- `npm run build` — production build to `dist/`
- `npm run preview` — serve the production build
- `npm run lint` — ESLint

## Architecture (short version)

- `src/pages` — one component per screen.
- `src/components` — reusable UI (phone frame, bottom nav, filter sheet, cards…).
- `src/api` — thin client; each module has a **mock** branch and a **real**
  branch (`VITE_USE_MOCK` toggles). Flip to `false` once the backend gaps in the
  review doc are fixed.
- `src/mocks` — offline catalogue + in-memory store mirroring `scripts/db_seed.sql`.
- `src/context/AuthContext` — auth state persisted to `localStorage`.
- `src/styles` — design tokens + base + components + screens (no CSS framework).

Mock images live in `public/mock/` and are intended to be swapped for real assets.
