import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import {
  SUPPORTED_LANGS,
  RTL_LANGS,
  detectBrowserLanguage,
  t as translate,
} from "../lib/i18n.js";

/**
 * Global language state.
 *
 * Resolution order (first-wins) on initial load:
 *   1. localStorage("trippop.lang") — user's prior choice
 *   2. navigator.language(s)        — narrowed to supported set
 *   3. "ko"                         — project default
 *
 * Side effects when lang changes:
 *   - persist to localStorage
 *   - update <html lang="..." dir="...">  → CSS can target [dir="rtl"]
 *
 * We accept a `defaultLang` prop so tests / SSR can inject a value.
 */

const STORAGE_KEY = "trippop.lang";

const LanguageContext = createContext(null);

function readStoredLang() {
  if (typeof window === "undefined") return null;
  try {
    const saved = window.localStorage.getItem(STORAGE_KEY);
    return SUPPORTED_LANGS.includes(saved) ? saved : null;
  } catch {
    // localStorage can throw in privacy mode / disabled storage.
    return null;
  }
}

function persistLang(lang) {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(STORAGE_KEY, lang);
  } catch {
    /* ignore */
  }
}

export function LanguageProvider({ children, defaultLang }) {
  const [lang, setLangState] = useState(() => {
    if (defaultLang && SUPPORTED_LANGS.includes(defaultLang)) return defaultLang;
    return readStoredLang() ?? detectBrowserLanguage();
  });

  // Keep <html lang> and <html dir> in sync. This is the single source of
  // truth for RTL — CSS uses [dir="rtl"] selectors instead of a JS flag so
  // every cascading rule (incl. third-party) flips correctly.
  useEffect(() => {
    if (typeof document === "undefined") return;
    document.documentElement.lang = lang;
    document.documentElement.dir = RTL_LANGS.includes(lang) ? "rtl" : "ltr";
  }, [lang]);

  const setLang = useCallback((next) => {
    if (!SUPPORTED_LANGS.includes(next)) return;
    persistLang(next);
    setLangState(next);
  }, []);

  // Bind t() to the current language so call sites don't need to pass it.
  const t = useCallback(
    (key, vars) => translate(key, lang, vars),
    [lang]
  );

  const value = useMemo(
    () => ({
      lang,
      setLang,
      t,
      isRTL: RTL_LANGS.includes(lang),
      supported: SUPPORTED_LANGS,
    }),
    [lang, setLang, t]
  );

  return (
    <LanguageContext.Provider value={value}>
      {children}
    </LanguageContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useLanguage() {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error("useLanguage must be used within <LanguageProvider>");
  }
  return ctx;
}
