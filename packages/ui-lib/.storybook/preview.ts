import type { Preview } from '@storybook/svelte';
import { withThemeByDataAttribute } from '@storybook/addon-themes';
import '../src/lib/styles/app.css';

const preview: Preview = {
	parameters: {
		controls: {
			matchers: {
				color: /(background|color)$/i,
				date: /Date$/i
			}
		}
	},

	tags: ['autodocs']
};

/* snipped for brevity */

export const decorators = [
	withThemeByDataAttribute({
		themes: {
			light: 'light',
			dark: 'dark'
		},
		defaultTheme: 'light',
		attributeName: 'data-theme'
	})
];

export default preview;
