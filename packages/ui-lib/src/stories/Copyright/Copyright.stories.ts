import type { Meta, StoryObj } from '@storybook/svelte';
import { Copyright } from '../../lib/components/Copyright/index.js';

// More on how to set up stories at: https://storybook.js.org/docs/writing-stories
const meta = {
	title: 'Example/Copyright',
	component: Copyright
	//tags: ['autodocs'],
	/*
  argTypes: {
    backgroundColor: { control: 'color' },
    size: {
      control: { type: 'select' },
      options: ['small', 'medium', 'large'],
    },
  },*/
} satisfies Meta<Copyright>;

export default meta;
type Story = StoryObj<typeof meta>;

// More on writing stories with args: https://storybook.js.org/docs/writing-stories/args
export const Primary: Story = {
	args: {
		label: 'Copyright'
	}
};

export const Secondary: Story = {
	args: {
		label: 'Copyright'
	}
};
