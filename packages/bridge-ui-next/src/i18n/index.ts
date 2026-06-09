"use client";

import i18n from "i18next";
import LanguageDetector from "i18next-browser-languagedetector";
import { initReactI18next } from "react-i18next";

import en from "./en.json";

/**
 * i18n singleton init — mirrors the original svelte-i18n setup:
 *  - bundles en.json (no http backend)
 *  - fallbackLng 'en'
 *  - LanguageDetector via navigator, load 'languageOnly' (replicates getLocaleFromNavigator)
 *  - single-brace interpolation `{key}` so en.json placeholders resolve without edits
 *
 * Guard against re-init under Fast Refresh / double-mount.
 */
if (!i18n.isInitialized) {
  i18n
    .use(LanguageDetector)
    .use(initReactI18next)
    .init({
      resources: {
        en: { translation: en },
      },
      fallbackLng: "en",
      load: "languageOnly",
      detection: {
        order: ["navigator"],
      },
      interpolation: {
        escapeValue: false,
        // Original svelte-i18n uses single-brace placeholders: {amount}
        prefix: "{",
        suffix: "}",
      },
      // dot keySeparator + colon nsSeparator are the i18next defaults — keep them.
    });
}

export default i18n;
