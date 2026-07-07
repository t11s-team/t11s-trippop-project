/**
 * Centered phone-shaped shell. Every screen renders inside this so the app
 * matches the mobile mockups on desktop and fills the viewport on phones.
 *
 * `footer` (e.g. <BottomNav/>) is pinned outside the scroll area.
 *
 * NOTE: The faux iOS StatusBar was removed — on real mobile it collided with
 * the device's own status bar and looked broken. The app now starts at the
 * brand header.
 */
export default function PhoneFrame({ children, variant, footer, scroll = true }) {
  return (
    <div className={`phone${variant === "auth" ? " phone--auth" : ""}`}>
      <div className={`phone__body${scroll ? " no-scrollbar" : ""}`}>{children}</div>
      {footer}
    </div>
  );
}
