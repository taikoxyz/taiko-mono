import daisyui from 'daisyui';

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

			fontSize: {
				h0: [
					'6.25rem',
					{
						lineHeight: '5.313rem'
					}
				],
				h4: [
					'1.375rem',
					{
						lineHeight: '1.75rem'
					}
				]
			},
			keyframes: {
				'cell-pulse-animation': {
					'0%': { opacity: '0' },
					'50%': { opacity: '1' },
					'100%': { opacity: '0' }
				},
				'cell-pulse-negative-animation': {
					'0%': { opacity: '1' },
					'50%': { opacity: '0' },
					'100%': { opacity: '1' }
				},
				'arrows-x-animation': {
					'0%': { left: '0' },
					'100%': { left: '100%' }
				}
			},
			animation: {
				'cell-pulse-3': 'cell-pulse-animation 3s ease-in infinite',
				'cell-pulse-5': 'cell-pulse-animation 5s ease-in infinite',
				'cell-pulse-7': 'cell-pulse-animation 7s ease-in infinite',
				'cell-pulse-negative-3': 'cell-pulse-negative-animation 3s ease-in infinite',
				'cell-pulse-negative-5': 'cell-pulse-negative-animation 5s ease-in infinite',
				'cell-pulse-negative-7': 'cell-pulse-negative-animation 7s ease-in infinite',
				'arrows-x-3': 'arrows-x-animation 300ms linear forwards',
				'arrows-x-3-reset': 'arrows-x-animation 300ms linear reverse'
			},
			colors: {
				// Pink
				'pink-10': '#FFE7F6',
				'pink-50': '#FFC6E9',
				'pink-200': '#FF6FC8',
				'pink-400': '#E81899',
				'pink-500': '#C8047D',
				// Gray
				'gray-0': '#FFFFFF',
				'gray-5': '#fafafa',
				'gray-10': '#F3F3F3',
				'gray-50': '#E3E3E3',
				'gray-100': '#CACBCE',
				'gray-200': '#ADB1B8',
				'gray-300': '#91969F',
				'gray-400': '#767C89',
				'gray-500': '#5D636F',
				'gray-600': '#444A55',
				'gray-700': '#2B303B',
				'gray-800': '#191E28',
				'gray-900': '#0B101B',
				'gray-1000': '#050912',
				// Red
				'red-10': '#FFE7E7',
				'red-300': '#F15C5D',
				'red-400': '#DB4546',
				'red-500': '#CE2C2D',
				'red-800': '#440000',
				// Green
				'green-10': '#E4FFF4',
				'green-300': '#47E0A0',
				'green-400': '#2DCA88',
				'green-600': '#059458',
				'green-700': '#005E36',
				// Yellow
				'yellow-10': '#FFF6DE',
				'yellow-300': '#F8C23B',
				'yellow-500': '#DBA00D',
				'yellow-700': '#775602',
				'yellow-800': '#382800',

				// Theme
				'test-content-primary': 'var(--test-content-primary)',
				'content-primary': 'var(--content-primary)',
				'content-secondary': 'var(--content-secondary)',
				'content-tertiary': 'var(--content-tertiary)',
				'content-link-primary': 'var(--content-link-primary)',
				'content-link-hover': 'var(--content-link-hover)',
				'icon-primary': 'var(--icon-primary)',
				'icon-secondary': 'var(--icon-secondary)',
				'brand-primary': 'var(--brand-primary)',
				'brand-secondary': 'var(--brand-secondary)',
				positive: 'var(--positive)',
				negative: 'var(--negative)',
				warning: 'var(--warning)',
				'background-primary': 'var(--background-primary)',
				'background-elevated': 'var(--background-elevated)',
				'background-neutral': 'var(--background-neutral)',
				'background-overlay': 'var(--background-overlay)',
				'interactive-primary': 'var(--interactive-primary)',
				'interactive-primary-accent': 'var(--interactive-primary-accent)',
				'interactive-secondary': 'var(--interactive-secondary)',
				'interactive-tertiary': 'var(--interactive-tertiary)',
				'interactive-accent': 'var(--interactive-accent)',
				'border-divider-default': 'var(--border-divider-default)',
				'border-primary': 'var(--border-primary)',
				'border-hover': 'var(--border-hover)',
				'border-accent': 'var(--border-accent)',
				'base-content-primary': 'var(--base-content-primary)',
				'base-background-primary': 'var(--base-background-primary)',
				// Custom
				'discord-purple': '#5765f1',

				// testing
				legacy: 'var(--primary-brand)'
			}
		}
	},

	plugins: [daisyui, require('tailwindcss-image-rendering')()],

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
					//...darkTheme,

					'color-scheme': 'dark',
					'--btn-text-case': 'capitalize',
					// '--rounded-box': '0.625rem', // 10px

					'--primary-brand': '#C8047D', // pink-500
					'--primary-content': '#F3F3F3', // grey-10
					'--primary-link': '#FF6FC8', // pink-200
					'--primary-link-hover': '#FFC6E9', // pink-50
					'--primary-icon': '#CACBCE', // grey-100
					'--primary-background': '#0B101B', // grey-900
					'--primary-interactive': '#C8047D', // pink-500
					'--primary-interactive-accent': '#E81899', // pink-400
					'--primary-interactive-hover': '#E81899', // pink-400
					'--primary-border-hover': '#FF6FC8', // pink-200
					'--primary-border-dark': '#5D636F', // grey-500
					'--primary-border-accent': '#E81899', // pink-400
					'--primary-base-background': '#FFFFFF', // grey-0
					'--primary-base-content': '#191E28', // grey-800

					'--secondary-brand': '#E81899', // pink-400
					'--secondary-content': '#ADB1B8', // grey-200
					'--secondary-icon': '#2B303B', // grey-700

					'--secondary-interactive-accent': '#2B303B', // grey-700
					'--secondary-interactive-hover': '#ADB1B8', // grey-200

					'--tertiary-content': '#5D636F', // grey-500
					'--tertiary-interactive-accent': '#5D636F', // grey-500
					'--tertiary-interactive-hover': '#444A55', // grey-600

					'--positive-sentiment': '#47E0A0', // green-300
					'--positive-background': '#00321D', // green-800

					'--negative-sentiment': '#F15C5D', // red-300
					'--negative-background': '#440000', // red-800

					'--warning-sentiment': '#EBB222', // yellow-400
					'--warning-background': '#382800', // yellow-800

					'--elevated-background': '#191E28', // grey-800
					'--neutral-background': '#2B303B', // grey-700
					'--neutral-content': '#2B303B', // grey-800
					'--neutral-accent': '#2B303B', // grey-700
					'--overlay-background': 'rgba(12, 17, 28, 0.5)', // grey-900|50%
					'--overlay-dialog': 'rgba(12, 17, 28, 0.90)', // grey-900|90%
					'--divider-border': '#444A55', // grey-600
					'--dialog-background': '#2B303B', // grey-700
					'--dialog-dialog-interactive-disabled': '#444A55', // grey-600

					// ==Taikoons Color Customizations==//
					'--grey-500-10': 'rgba(93, 99, 111, 0.1)', // grey-500, 10% opacity
					'--grey-500-20': 'rgba(93, 99, 111, 0.2)', // grey-500, 20% opacity

					'--text-dark': '#f3f3f3',
					'--text-light': '#444A55', // grey-600

					'--neutral': '#2B303B', // grey-700

					// figma's theme
					'--interactive-primary-pink': '#C8047D', // pink 500
					'--interactive-primary-accent': '#E81899', // pink-400
					'--interactive-secondary': '#2b303b', // grey-700
					'--interactive-tertiary': '#444a55', // grey-600
					'--interactive-accent': '#5D636F', // grey-500

					'--content-primary': '#F3F3F3', // grey-10
					'--content-secondary': '#ADB1B8', // grey-200
					'--content-tertiary': '#5D636F', // grey-500
					'--content-link-primary': '#FF6FC8', // pink-200
					'--content-link-hover': '#FFC6E9', // pink-50

					'--border-divider-default': '#444A55', // grey-600

					'--background-primary': '#0B101B', // grey-900
					'--background-neutral': '#2B303B', // grey-700
					'--background-elevated': '#191E28', // grey-800

					'--icon-primary': '#CACBCE', // grey-100
					'--icon-secondary': '#2B303B', // grey-700

					// custom colors

					'--background-body': '#0b101b',
					'--nav-button': '#2B303B',
					// ================================ //

					primary: '#C8047D', // pink-500,
					'primary-focus': '#E81899', // pink-400
					'primary-content': '#F3F3F3', // grey-10

					secondary: '#E81899', // pink-400
					// 'secondary-focus': '',
					'secondary-content': '#ADB1B8', // grey-200

					neutral: '#2B303B', // grey-700
					'neutral-focus': '#444A55', // grey-600
					'neutral-content': '#F3F3F3', // grey-10

					'base-100': '#0B101B', // grey-900
					// 'base-200': '',
					// 'base-300': '',
					'base-content': '#F3F3F3', // grey-10

					success: '#00321D', // green-800
					'success-content': '#47E0A0', // green-300
					error: '#440000', // red-800
					'error-content': '#F15C5D', // red-300
					warning: '#382800', // yellow-800
					'warning-content': '#EBB222' // yellow-400
				},

				light: {
					//...lightTheme,
					'color-scheme': 'light',
					'--btn-text-case': 'capitalize',

					'--primary-brand': '#C8047D', // pink-500
					'--primary-content': '#191E28', // grey-800
					'--primary-link': '#C8047D', // pink-500
					'--primary-link-hover': '#E81899', // pink-400
					'--primary-icon': '#5D636F', // grey-500
					'--primary-background': '#FAFAFA', // grey-5
					'--primary-interactive': '#C8047D', // pink-500
					'--primary-interactive-accent': '#E81899', // pink-400
					'--primary-interactive-hover': '#E3E3E3', //grey-50
					'--primary-border-hover': '#FF6FC8', // pink-200
					'--primary-border-accent': '#E81899', // pink-400

					// TODO: these two are yet to be decided
					'--primary-base-background': '#FFFFFF', // grey-0
					'--primary-base-content': '#191E28', // grey-800

					'--secondary-brand': '#E81899', // pink-400
					'--secondary-content': '#444A55', // grey-600
					'--secondary-icon': '#2B303B', // grey-700
					'--secondary-interactive-accent': '#E3E3E3', // grey-50
					'--secondary-interactive-hover': '##F3F3F3', // grey-10

					'--tertiary-content': '#91969F', // grey-300

					// TODO: these two are missing. Remain the same as dark theme
					'--tertiary-interactive-hover': '#444A55', // grey-600
					'--tertiary-interactive-accent': '#5D636F', // grey-500

					'--positive-sentiment': '#005E36', // green-700
					'--positive-background': '#BFFFE4', // green-50

					'--negative-sentiment': '#BB1A1B', // red-600
					'--negative-background': '#FFE7E7', // red-10

					'--warning-sentiment': '#775602', // yellow-700
					'--warning-background': '#FFF6DE', // yellow-10

					'--elevated-background': '#e3e3e3', //#FAFAFA', // grey-5
					'--neutral-background': '#FFFFFF', //  grey-0
					'--neutral-content': '#191E28', // grey-800
					'--neutral-accent': '#e3e3e3', // grey-50
					'--overlay-background': 'rgba(12, 17, 28, 0.2)', // grey-900|20%
					'--overlay-dialog': 'rgba(12, 17, 28, 0.9)', // grey-900|20

					'--dialog-background': '#FFFFFF', // grey-0
					'--dialog-dialog-interactive-disabled': '#E3E3E3', // grey-50

					'--divider-border': '#CACBCE', // grey-100
					// ==Taikoons Color Customizations==//

					'--grey-500-10': 'rgba(250,250,250,0.5)',
					'--grey-500-20': 'rgba(250,250,250,0.5)',
					'--text-dark': '#191e28',
					'--text-light': '#91969f',
					'--neutral': '#E3E3E3', // grey-50

					// figma's theme
					'--interactive-primary-pink': '#C8047D', // pink 500
					'--interactive-primary-accent': '#E81899', // pink-400
					'--interactive-secondary': '#f3f3f3', // grey-10
					'--interactive-tertiary': '#e3e3e3', // grey-50
					'--interactive-accent': '#cacbce', // grey-100

					'--content-primary': '#191E28', // grey-800
					'--content-secondary': '#444A55', // grey-600
					'--content-tertiary': '#91969F', // grey-300
					'--content-link-primary': '#C8047D', // pink-500
					'--content-link-hover': '#E81899', // pink-400

					'--border-divider-default': '#CACBCE', // grey-100

					'--background-primary': '#ffffff', // grey-5
					'--background-neutral': '#F8f8f8', // grey-50
					'--background-elevated': '#ffffff', // grey-5

					'--icon-primary': '#5D636F', // grey-500
					'--icon-secondary': '#e3e3e3', // grey-50

					// custom colors

					'--background-body': '#f8f8f8',
					'--nav-button': '#ffffff',
					// ================================ //

					primary: '#C8047D', // pink-500,
					'primary-focus': '#E81899', // pink-400
					'primary-content': '#191E28', // grey-800

					secondary: '#E81899', // pink-400
					// 'secondary-focus': '',
					'secondary-content': '#444A55', // grey-600

					neutral: '#E3E3E3', // grey-50
					'neutral-focus': '#CACBCE', // grey-100
					'neutral-content': '#191E28', // grey-800

					'base-100': '#FAFAFA', // grey-5
					// 'base-200': '',
					// 'base-300': '',
					'base-content': '#191E28', // grey-800

					success: '#BFFFE4', // green-50
					'success-content': '#005E36', // green-700
					error: '#FFE7E7', // red-10
					'error-content': '#BB1A1B', // red-600
					warning: '#FFF6DE', // yellow-10
					'warning-content': '#775602' // yellow-700
				}
			}
		]
	}
};
