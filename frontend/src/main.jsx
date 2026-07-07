import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import { LanguageProvider } from './context/LanguageContext.jsx'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {/* LanguageProvider wraps App so every screen + AuthProvider can use t() / lang. */}
    <LanguageProvider>
      <App />
    </LanguageProvider>
  </StrictMode>,
)
