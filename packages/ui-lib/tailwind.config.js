import daisyuiPlugin from 'daisyui';
import colors from './src/lib/theme/colors';
import darkTheme from './src/lib/theme/dark-mode';
import lightTheme from './src/lib/theme/light-mode';

/** @type {import('tailwindcss').Config} */
export default {
	darkMode: ['class', '[data-theme="dark"]'],
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			fontFamily: {
				'clash-grotesk': 'ClashGrotesk-Medium'
			},
			backgroundImage: {
				footer: "url('/bg/footer-gradient.svg')",
				general: "url('/bg/general-gradient.svg')"
			},
			colors: {
				tko: colors
			}
		}
	},

	plugins: [daisyuiPlugin, require('tailwindcss-image-rendering')()],

	// https://daisyui.com/docs/config/
	daisyui: {
		darkTheme: 'dark', // name of one of the included themes for dark mode
		base: true, // applies background color and foreground color for root element by default
		styled: true, // include daisyUI colors and design decisions for all components
		utils: true, // adds responsive and modifier utility classes
		rtl: false, // rotate style direction from left-to-right to right-to-left. You also need to add dir="rtl" to your html tag and install `tailwindcss-flip` plugin for Tailwind CSS.
		prefix: '', // prefix for daisyUI classnames (components, modifiers and responsive class names. Not colors)
		logs: false, // Shows info about daisyUI version and used config in the console when building your CSS
		themes: [
			{
				dark: {
					...darkTheme
				},

				light: {
					...lightTheme
				}
			}
		]
	}
};
