/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],
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
  darkMode: "class",
};
