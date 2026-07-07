/** Faux iOS-style status bar to match the mockups (purely decorative). */
export default function StatusBar() {
  return (
    <div className="statusbar" aria-hidden="true">
      <span>9:41</span>
      <span className="statusbar__icons">
        {/* signal */}
        <svg width="18" height="12" viewBox="0 0 18 12" fill="currentColor">
          <rect x="0" y="8" width="3" height="4" rx="1" />
          <rect x="5" y="5" width="3" height="7" rx="1" />
          <rect x="10" y="2" width="3" height="10" rx="1" />
          <rect x="15" y="0" width="3" height="12" rx="1" opacity="0.35" />
        </svg>
        {/* wifi */}
        <svg width="16" height="12" viewBox="0 0 16 12" fill="currentColor">
          <path d="M8 11.5l2-2.4a2.8 2.8 0 00-4 0l2 2.4z" />
          <path d="M3.2 6.3a7 7 0 019.6 0l-1.3 1.4a5 5 0 00-7 0L3.2 6.3z" opacity="0.9" />
          <path d="M.8 3.7a10.5 10.5 0 0114.4 0l-1.3 1.4a8.5 8.5 0 00-11.8 0L.8 3.7z" opacity="0.75" />
        </svg>
        {/* battery */}
        <svg width="26" height="12" viewBox="0 0 26 12" fill="none">
          <rect x="0.5" y="0.5" width="22" height="11" rx="3" stroke="currentColor" />
          <rect x="2" y="2" width="18" height="8" rx="1.5" fill="currentColor" />
          <rect x="24" y="4" width="2" height="4" rx="1" fill="currentColor" />
        </svg>
      </span>
    </div>
  );
}
