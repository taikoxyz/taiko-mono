const colors = require("tailwindcss/colors");
module.exports = {
    content: ["./src/**/*.{html,js,svelte,ts}"],
    plugins: [require("daisyui")],
    darkMode: ['[data-theme="dark"]'],
    theme: {
        extend: {
          colors: {
            "dark-1": "var(--color-dark-1)",
            "dark-2": "var(--color-dark-2)",
            "dark-3": "var(--color-dark-3)",
            "dark-4": "var(--color-dark-4)",
            "dark-5": "var(--color-dark-5)",
            "dark-6": "var(--color-dark-6)",
            "transaction-table": "var(--color-transaction-table)",
            "bridge-form": "var(--color-bridge-form)",
          },
          keyframes: {
            rise: {
              '0%': { position: 'absolute', bottom: '-10px' },
              // '100%': { position: 'static' },
            }
          },
          animation: {
            rise: 'rise 0.5s ease-in-out',
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
                "accent-focus": "#E30EAD",
                "accent-content": "#F3F3F3",
                "neutral": "#242424",
                "base-100": "#0F0F0F",
                "info": "#373737",
                "success": "#008000",
                "warning": "#FFFF00",
                "error": "#FF0000",
                "--color-dark-1": "#000000",
                "--color-dark-2": "#181818",
                "--color-dark-3": "#0F0F0F",
                "--color-dark-4": "#242424",
                "--color-dark-5": "#373737",
                "--color-dark-6": "#4F4F4F",
                "--color-transaction-table": "#FFFFFF",
                "--rounded-btn": "1rem",
                "--btn-text-case": "capitalize",
                "--rounded-box": "18px",
                "--color-bridge-form": colors.zinc[800],
              },
              light: {
                ...require("daisyui/colors/themes")["[data-theme=light]"],
                "accent": "#FC0FC0",
                "accent-focus": "#E30EAD",
                "accent-content": "#F3F3F3",
                "neutral": "#d4d4d4",
                "neutral-focus": "#a3a3a3",
                "neutral-content": "#181818",
                "base-100": "#FAFAFA",
                "info": "#373737",
                "success": "#008000",
                "warning": "#FFFF00",
                "error": "#FF0000",
                "--color-dark-1": "#000000",
                "--color-dark-2": "#FFFFFF",
                "--color-dark-3": "#FAFAFA",
                "--color-dark-4": "#242424",
                "--color-dark-5": "#CDCDCD",
                "--color-dark-6": "#4F4F4F",
                "--color-transaction-table": "#1F2937",
                "--rounded-btn": "1rem",
                "--btn-text-case": "capitalize",
                "--rounded-box": "18px",
                "--color-bridge-form": colors.zinc[200],
              },
            },
          ],
    }
};
