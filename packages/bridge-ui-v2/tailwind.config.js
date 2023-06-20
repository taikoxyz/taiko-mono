import daisyuiPlugin from 'daisyui';

/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
      colors: {
        white: '#FFFFFF',
        black: '#000000',
        pink: {
          10: '#FFE7F6',
          50: '#FFC6E9',
          200: '#FF6FC8',
          400: '#E81899',
          500: '#C8047D',
        },
        grey: {
          0: '#FFFFFF',
          5: '#FAFAFA',
          10: '#F3F3F3',
          50: '#E7E7E7',
          100: '#CACBCE',
          200: '#ADB1B8',
          300: '#91969F',
          400: '#767C89',
          500: '#5D636F',
          600: '#444A55',
          700: '#2B303B',
          800: '#191E28',
          900: '#0B101B',
          1000: '#050912',
        },
        red: {
          10: '#FFE7E7',
          300: '#F15C5D',
          400: '#DB4546',
          500: '#CE2C2D',
          800: '#440000',
        },
        green: {
          10: '#E4FFF4',
          300: '#47E0A0',
          400: '#2DCA88',
          500: '#19BA76',
          800: '#00321D',
        },
        yellow: {
          10: '#FFF6DE',
          300: '#F8C23B',
          400: '#DBA00D',
          500: '#775602',
          800: '#382800',
        }
      }
  },
  darkMode: 'class',
  plugins: [daisyuiPlugin],

  // daisyUI config (optional - here are the default values)
  daisyui: {
    darkTheme: "dark", // name of one of the included themes for dark mode
    base: false, // applies background color and foreground color for root element by default
    styled: false, // include daisyUI colors and design decisions for all components
    utils: true, // adds responsive and modifier utility classes
    rtl: false, // rotate style direction from left-to-right to right-to-left. You also need to add dir="rtl" to your html tag and install `tailwindcss-flip` plugin for Tailwind CSS.
    prefix: "", // prefix for daisyUI classnames (components, modifiers and responsive class names. Not colors)
    logs: true, // Shows info about daisyUI version and used config in the console when building your CSS
    themes: [{
      dark: {
        primary: '#C8047D',
        secondary: '#E81899',
        success: '#47E0A0', // green-300
        error: '#F15C5D', // red-300
        warning: '#DBA00D', // yellow-400
      },
      light: {}
    }],

  },
};

// brand: {
//   dark: {
//     primary: '#C8047D',
//     secondary: '#E81899',
//   },
//   light: {},
// },
// bg: {
//   dark: {
//     primary: '#0B101B',
//     elevated: '#191E28',
//   },
//   light: {},
// },
// sentiment: {
//   dark: {
//     positive: '#47E0A0',
//     negative: '#F15C5D',
//     warning: '#F8C23B',
//   }
// }
