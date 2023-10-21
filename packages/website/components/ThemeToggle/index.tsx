// source: https://github.com/drizzle-team/drizzle-orm-docs
import React, { useEffect, useState } from "react";
import { useTheme } from "next-themes";
import styles from "./ThemeToggle.module.css";

const ThemeToggle = () => {
  const [isDark, setIsDark] = useState<boolean | null>(null);
  const { theme, setTheme } = useTheme();

  useEffect(() => {
    setIsDark(theme === "dark");
  }, [theme]);

  useEffect(() => {
    if (theme === "system") {
      const isLight = document.documentElement.classList.contains("light");
      setTheme(isLight ? "light" : "dark");
    }
  }, []);

  const toggleTheme = () => {
    setTheme(theme === "light" ? "dark" : "light");
  };
  return (
    <div className={styles.container} onClick={toggleTheme}>
      {isDark !== null && (
        <>
          <div className={styles.line} />
          <div
            className={`${styles.circle} ${
              isDark ? styles.dark : styles.light
            }`}
          >
            {isDark ? (
              <div>
                <svg
                  fill="none"
                  viewBox="2 2 20 20"
                  width="12"
                  height="12"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    fill="currentColor"
                    d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z"
                  />
                </svg>
              </div>
            ) : (
              <div>
                <svg
                  fill="none"
                  viewBox="3 3 18 18"
                  width="12"
                  height="12"
                  stroke="currentColor"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    fill="currentColor"
                    d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"
                  />
                </svg>
              </div>
            )}
          </div>
        </>
      )}
    </div>
  );
};

export { ThemeToggle };
