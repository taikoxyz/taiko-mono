import type { Meta, StoryObj } from '@storybook/svelte';
import { default as Component } from './Component.svelte';
import colors from '../../lib/theme/colors'
// More on how to set up stories at: https://storybook.js.org/docs/writing-stories
const meta = {
	title: 'Colors',
	component: Component,
	tags: [],
	//tags: ['autodocs'],
	argTypes: {
        color: {control: 'select', options: Object.keys(colors)
        }
		//label: { control: 'text' },
		//title: { control: 'text' },
		//text: { control: 'text' }
	}

	/*
  argTypes: {
    backgroundColor: { control: 'color' },
    size: {
      control: { type: 'select' },
      options: ['small', 'medium', 'large'],
    },
  },*/
} satisfies Meta<Component>;

export default meta;
type Story = StoryObj<typeof meta>;

// More on writing stories with args: https://storybook.js.org/docs/writing-stories/args
export const Primary: Story = {
	args: {
        color: 'pink-500'
	}
};
