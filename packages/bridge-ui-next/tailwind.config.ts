import type { Config } from "tailwindcss";
import tailwindcssAnimate from "tailwindcss-animate";
import daisyui from "daisyui";

// daisyUI augments the Tailwind config with a top-level `daisyui` key.
type ConfigWithDaisyUI = Config & { daisyui?: Record<string, unknown> };

const config: ConfigWithDaisyUI = {
  // Theme is driven by the data-theme attribute on <html> (values 'light' | 'dark'),
  // matching the original bridge-ui daisyUI setup — NOT shadcn's default `.dark` class.
  darkMode: ["class", '[data-theme="dark"]'],
  content: [
    "./src/app/**/*.{ts,tsx}",
    "./src/components/**/*.{ts,tsx}",
    "./src/libs/**/*.{ts,tsx}",
    "./src/**/*.{ts,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["var(--font-public-sans)", "Public Sans", "sans-serif"],
        display: ["Clash Grotesk", "sans-serif"],
      },
      width: {
        dvw: "100dvw",
      },
      colors: {
        // Fixed numeric palette — identical across both themes (verbatim from original).
        blue: {
          0: "#FFFFFF",
          5: "#F3F8FF",
          10: "#E7F1FF",
          50: "#C1DFFF",
          100: "#8DC4FF",
          200: "#5AAAFF",
          300: "#2C8FFF",
          400: "#006AFF",
          500: "#0052CC",
          600: "#003E99",
          700: "#002966",
          800: "#001833",
          900: "#000C0D",
          1000: "#050912",
        },
        grey: {
          0: "#FFFFFF",
          5: "#FAFAFA",
          10: "#F3F3F3",
          50: "#E3E3E3",
          100: "#CACBCE",
          200: "#ADB1B8",
          300: "#91969F",
          400: "#767C89",
          500: "#5D636F",
          600: "#444A55",
          700: "#2B303B",
          800: "#191E28",
          900: "#0B101B",
          1000: "#050912",
        },
        pink: {
          0: "#FFFFFF",
          5: "#FFF8FC",
          10: "#FFE7F6",
          50: "#FFC6E9",
          100: "#FF98D8",
          200: "#FF6FC8",
          300: "#FF40B6",
          400: "#E81899",
          500: "#C8047D",
          600: "#9A0060",
          700: "#7D004E",
          800: "#4B002F",
          900: "#240017",
          1000: "#050912",
        },
        red: {
          0: "#FFFFFF",
          5: "#FEF5F5",
          10: "#FFE7E7",
          50: "#FFC5C5",
          100: "#FF9B9C",
          200: "#FD7576",
          300: "#F15C5D",
          400: "#DB4546",
          500: "#CE2C2D",
          600: "#BB1A1B",
          700: "#790102",
          800: "#440000",
          900: "#250000",
          1000: "#050912",
        },
        green: {
          0: "#FFFFFF",
          5: "#F2FFFA",
          10: "#E4FFF4",
          50: "#BFFFE4",
          100: "#89FFCD",
          200: "#65F0B6",
          300: "#47E0A0",
          400: "#2DCA88",
          500: "#19BA76",
          600: "#059458",
          700: "#005E36",
          800: "#00321D",
          900: "#001C10",
          1000: "#050912",
        },
        yellow: {
          0: "#FFFFFF",
          5: "#FFFCF3",
          10: "#FFF6DE",
          50: "#FFEAB5",
          100: "#FFDC85",
          200: "#FFCF55",
          300: "#F8C23B",
          400: "#EBB222",
          500: "#DBA00D",
          600: "#C28B00",
          700: "#775602",
          800: "#382800",
          900: "#201700",
          1000: "#050912",
        },
        // Semantic colors — reference CSS vars so they auto-flip per [data-theme].
        primary: {
          DEFAULT: "var(--primary-brand)",
          brand: "var(--primary-brand)",
          content: "var(--primary-content)",
          link: {
            DEFAULT: "var(--primary-link)",
            hover: "var(--primary-link-hover)",
          },
          icon: "var(--primary-icon)",
          background: "var(--primary-background)",
          interactive: {
            DEFAULT: "var(--primary-interactive)",
            accent: "var(--primary-interactive-accent)",
            hover: "var(--primary-interactive-hover)",
          },
          border: {
            DEFAULT: "var(--primary-border)",
            dark: "var(--primary-border-dark)",
            hover: "var(--primary-border-hover)",
            accent: "var(--primary-border-accent)",
          },
          base: {
            content: "var(--primary-base-content)",
            background: "var(--primary-base-background)",
          },
        },
        secondary: {
          DEFAULT: "var(--secondary-brand)",
          brand: "var(--secondary-brand)",
          content: "var(--secondary-content)",
          icon: "var(--secondary-icon)",
          interactive: {
            accent: "var(--primary-interactive-accent)",
            hover: "var(--secondary-interactive-hover)",
          },
        },
        tertiary: {
          content: "var(--tertiary-content)",
          interactive: {
            accent: "var(--tertiary-interactive-accent)",
          },
        },
        positive: {
          sentiment: "var(--positive-sentiment)",
          background: "var(--positive-background)",
        },
        negative: {
          sentiment: "var(--negative-sentiment)",
          background: "var(--negative-background)",
        },
        warning: {
          sentiment: "var(--warning-sentiment)",
          background: "var(--warning-background)",
        },
        dialog: {
          background: "var(--dialog-background)",
          interactive: {
            disabled: "var(--dialog-dialog-interactive-disabled)",
          },
        },
        "elevated-background": "var(--elevated-background)",
        "neutral-background": "var(--neutral-background)",
        "overlay-background": "var(--overlay-background)",
        "divider-border": "var(--divider-border)",
      },
      boxShadow: {
        "box-small": "0px 10px 48px 0px rgba(5, 9, 18, 0.3)",
        "box-large": "0px 20px 66px 0px rgba(5, 9, 18, 0.48)",
      },
      borderRadius: {
        // shadcn-compatible radius tokens
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [tailwindcssAnimate, daisyui],

  // daisyUI config — ported verbatim from the original bridge-ui tailwind.config.js
  // so component classes (drawer, menu, btn, steps, modal, tabs, toggle, …) and
  // the light/dark theme CSS variables render identically to the original.
  daisyui: {
    darkTheme: "dark",
    base: true,
    styled: true,
    utils: true,
    rtl: false,
    prefix: "",
    logs: false,
    themes: [
      {
        dark: {
          "color-scheme": "dark",
          "--btn-text-case": "capitalize",

          "--primary-brand": "#C8047D",
          "--primary-content": "#F3F3F3",
          "--primary-link": "#FF6FC8",
          "--primary-link-hover": "#FFC6E9",
          "--primary-icon": "#CACBCE",
          "--primary-background": "#0B101B",
          "--primary-interactive": "#C8047D",
          "--primary-interactive-accent": "#E81899",
          "--primary-interactive-hover": "#E81899",
          "--primary-border-hover": "#FF6FC8",
          "--primary-border-dark": "#5D636F",
          "--primary-border-accent": "#E81899",
          "--primary-base-background": "#FFFFFF",
          "--primary-base-content": "#191E28",

          "--secondary-brand": "#E81899",
          "--secondary-content": "#ADB1B8",
          "--secondary-icon": "#2B303B",
          "--secondary-interactive-accent": "#2B303B",
          "--secondary-interactive-hover": "#ADB1B8",

          "--tertiary-content": "#5D636F",
          "--tertiary-interactive-accent": "#5D636F",
          "--tertiary-interactive-hover": "#444A55",

          "--positive-sentiment": "#47E0A0",
          "--positive-background": "#00321D",

          "--negative-sentiment": "#F15C5D",
          "--negative-background": "#440000",

          "--warning-sentiment": "#EBB222",
          "--warning-background": "#382800",

          "--neutral-sentiment": "#0052CC",
          "--neutral-sentiment-background": "#002966",

          "--elevated-background": "#191E28",
          "--neutral-background": "#2B303B",
          "--neutral-content": "#2B303B",
          "--neutral-accent": "#2B303B",
          "--overlay-background": "rgba(12, 17, 28, 0.5)",
          "--overlay-dialog": "rgba(12, 17, 28, 0.90)",
          "--divider-border": "#444A55",

          "--dialog-background": "#2B303B",
          "--dialog-dialog-interactive-disabled": "#444A55",

          primary: "#C8047D",
          "primary-focus": "#E81899",
          "primary-content": "#F3F3F3",

          secondary: "#E81899",
          "secondary-content": "#ADB1B8",

          neutral: "#2B303B",
          "neutral-focus": "#444A55",
          "neutral-content": "#F3F3F3",

          "base-100": "#0B101B",
          "base-content": "#F3F3F3",

          success: "#00321D",
          "success-content": "#47E0A0",
          error: "#440000",
          "error-content": "#F15C5D",
          warning: "#382800",
          "warning-content": "#EBB222",
        },

        light: {
          "color-scheme": "light",
          "--btn-text-case": "capitalize",

          "--primary-brand": "#C8047D",
          "--primary-content": "#191E28",
          "--primary-link": "#C8047D",
          "--primary-link-hover": "#E81899",
          "--primary-icon": "#5D636F",
          "--primary-background": "#FAFAFA",
          "--primary-interactive": "#C8047D",
          "--primary-interactive-accent": "#E81899",
          "--primary-interactive-hover": "#E3E3E3",
          "--primary-border-hover": "#FF6FC8",
          "--primary-border-accent": "#E81899",

          "--primary-base-background": "#FFFFFF",
          "--primary-base-content": "#191E28",

          "--secondary-brand": "#E81899",
          "--secondary-content": "#444A55",
          "--secondary-icon": "#2B303B",
          "--secondary-interactive-accent": "#E3E3E3",
          "--secondary-interactive-hover": "#F3F3F3",

          "--tertiary-content": "#91969F",
          "--tertiary-interactive-hover": "#444A55",
          "--tertiary-interactive-accent": "#5D636F",

          "--positive-sentiment": "#005E36",
          "--positive-background": "#BFFFE4",

          "--negative-sentiment": "#BB1A1B",
          "--negative-background": "#FFE7E7",

          "--warning-sentiment": "#775602",
          "--warning-background": "#FFF6DE",

          "--elevated-background": "#FAFAFA",
          "--neutral-background": "#FFFFFF",
          "--neutral-content": "#191E28",
          "--neutral-accent": "#e3e3e3",
          "--overlay-background": "rgba(12, 17, 28, 0.2)",
          "--overlay-dialog": "rgba(12, 17, 28, 0.9)",

          "--dialog-background": "#FFFFFF",
          "--dialog-dialog-interactive-disabled": "#E3E3E3",

          "--divider-border": "#CACBCE",

          primary: "#C8047D",
          "primary-focus": "#E81899",
          "primary-content": "#191E28",

          secondary: "#E81899",
          "secondary-content": "#444A55",

          neutral: "#E3E3E3",
          "neutral-focus": "#CACBCE",
          "neutral-content": "#191E28",

          "base-100": "#FAFAFA",
          "base-content": "#191E28",

          success: "#BFFFE4",
          "success-content": "#005E36",
          error: "#FFE7E7",
          "error-content": "#BB1A1B",
          warning: "#FFF6DE",
          "warning-content": "#775602",
        },
      },
    ],
  },
};

export default config;
