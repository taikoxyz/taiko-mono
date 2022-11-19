/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        taiko: {
          pink: {
            DEFAULT: "#E28BFD",
          },
          blue: {
            DEFAULT: "#000032",
          }
        }
      }
    },
  },
  plugins: [],
}