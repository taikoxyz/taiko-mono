import type { Meta, StoryObj } from '@storybook/svelte';
import { Icons } from '../../lib/components/Icons/index.js';

const icon = Icons.AngleDownSolid;
// More on how to set up stories at: https://storybook.js.org/docs/writing-stories
const meta = {
	title: 'Example/Icons',
	component: icon
	//tags: ['autodocs'],
	/*
  argTypes: {
    backgroundColor: { control: 'color' },
    size: {
      control: { type: 'select' },
      options: ['small', 'medium', 'large'],
    },
  },*/
} satisfies Meta<typeof icon>;

export default meta;
type Story = StoryObj<typeof meta>;

// More on writing stories with args: https://storybook.js.org/docs/writing-stories/args
export const Primary: Story = {
	args: {
		label: 'Icons'
	}
};

export const Secondary: Story = {
	args: {
		label: 'Icons'
	}
};
