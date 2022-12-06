module.exports = {
    content: ["./src/**/*.{html,js,svelte,ts}"],
    plugins: [require("daisyui")],
    theme: {
        extend: {
          colors: {
            "dark-1": "var(--color-dark-1)",
            "dark-2": "var(--color-dark-2)",
            "dark-3": "var(--color-dark-3)",
            "dark-4": "var(--color-dark-4)",
            "dark-5": "var(--color-dark-5)",
            "dark-6": "var(--color-dark-6)",
          }
        }
    },
    daisyui: {
        styled: true,
        themes: true,
        base: true,
        utils: true,
        logs: true,
        rtl: false,
        prefix: "",
        darkTheme: "dark",
        themes: [
            {
              dark: {
                ...require("daisyui/colors/themes")["[data-theme=black]"],
                "primary": "#242424",
                "secondary": "#181818",
                "accent": "#FC0FC0",
                "accent-focus": "#B20F89",
                "accent-content": "#F3F3F3",
                "neutral": "#242424",
                "base-100": "#0f0f0f",
                "info": "#373737",
                "success": "#008000",
                "warning": "#FFFF00",
                "error": "#FF0000",
                "--color-dark-1": "#000000",
                "--color-dark-2": "#0F0F0F",
                "--color-dark-3": "#181818",
                "--color-dark-4": "#242424",
                "--color-dark-5": "#373737",
                "--color-dark-6": "#4F4F4F",
                "--rounded-btn": "1rem",
                "--btn-text-case": "capitalize",
                "--rounded-box": "18px",
              },
            },
          ],
    }
};
