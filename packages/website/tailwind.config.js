/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,jsx,ts,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        oxanium: ["Oxanium", "sans-serif"],
      },
    },
  },
  plugins: [],
  corePlugins: {
    container: false,
    preflight: false,
  },
  darkMode: ["class", '[data-theme="dark"]'],
};
