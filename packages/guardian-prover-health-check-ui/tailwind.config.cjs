module.exports = {
    content: ["./src/**/*.{html,js,svelte}"],  theme: {
    extend: {},
  },
  plugins: [
    require("daisyui")
  ],
  daisyui: {
    themes: ["dark"]
  }
}