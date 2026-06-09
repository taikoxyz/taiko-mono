"use client";

import { useTranslation as useReactI18nextTranslation } from "react-i18next";

/**
 * App-wide i18n hook. Migrated components use:
 *
 *   const { t } = useTranslation();
 *   t('bridge.title');
 *   t('bridge.amount', { amount });  // single-brace interpolation
 *
 * This wraps react-i18next so every component imports from one place
 * (`@/i18n/useTranslation`) and we can swap the impl later if needed.
 */
export function useTranslation() {
  return useReactI18nextTranslation();
}

export default useTranslation;
