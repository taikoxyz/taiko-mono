const daisyuiPlugin = require("daisyui");

/** @type {import('tailwindcss').Config} */
export default {
  content: ["./src/**/*.{html,js,svelte,ts}"],

  theme: {
    extend: {},
  },

  plugins: [daisyuiPlugin],

  daisyui: {
    // https://daisyui.com/docs/config/
    styled: true,
    themes: true,
    base: true,
    utils: true,
    logs: true,
    rtl: false,
    prefix: "",
    darkTheme: "dark",

    // https://daisyui.com/docs/themes/
    themes: [
      {
        dark: {},
        light: {},
      },
    ],
  },
};
