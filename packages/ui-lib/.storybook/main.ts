import type { StorybookConfig } from '@storybook/sveltekit';

export const framework = {
	name: '@storybook/sveltekit',
	options: {}
};

export const docs = { autodocs: false };
export const addons = ['@storybook/addon-essentials'];

const config: StorybookConfig = {
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
