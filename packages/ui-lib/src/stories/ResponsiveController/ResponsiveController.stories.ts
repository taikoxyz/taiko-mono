import type { Meta, StoryObj } from '@storybook/svelte';
import { ResponsiveController } from '../../lib/components/ResponsiveController/index.js';

// More on how to set up stories at: https://storybook.js.org/docs/writing-stories
const meta = {
	title: 'Example/ResponsiveController',
	component: ResponsiveController
	//tags: ['autodocs'],
	/*
  argTypes: {
    backgroundColor: { control: 'color' },
    size: {
      control: { type: 'select' },
      options: ['small', 'medium', 'large'],
    },
  },*/
} satisfies Meta<ResponsiveController>;

export default meta;
type Story = StoryObj<typeof meta>;

// More on writing stories with args: https://storybook.js.org/docs/writing-stories/args
export const Primary: Story = {
	args: {
		//	label: 'ResponsiveController'
	}
};

export const Secondary: Story = {
	args: {
		//	label: 'ResponsiveController'
	}
};
