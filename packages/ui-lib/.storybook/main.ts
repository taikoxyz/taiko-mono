import type { StorybookConfig } from '@storybook/sveltekit';

export const framework = {
	name: '@storybook/sveltekit',
	options: {}
};

export const docs = { autodocs: false };
export const addons = [
	'@storybook/addon-links',
	'@storybook/addon-essentials',
	'@chromatic-com/storybook',
	'@storybook/addon-interactions'
];

const config: StorybookConfig = {
	//framework: '@taiko/ui-lib',
	stories: ['../src/**/*.mdx', '../src/**/*.stories.@(js|jsx|mjs|ts|tsx)'],
	staticDirs: ['../static'],
	framework: {
		name: '@storybook/sveltekit',
		options: {}
	},
	addons,
	docs
};

export default config;
