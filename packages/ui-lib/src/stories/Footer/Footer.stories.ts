import type { Meta, StoryObj } from '@storybook/svelte';
import { Footer } from '../../lib/components/Footer';

// More on how to set up stories at: https://storybook.js.org/docs/writing-stories
const meta = {
	title: 'Footer',
	component: Footer,
	tags: [],
	//tags: ['autodocs'],
	argTypes: {
		label: { control: 'text' },
		title: { control: 'text' },
		text: { control: 'text' }
	}

	/*
  argTypes: {
    backgroundColor: { control: 'color' },
    size: {
      control: { type: 'select' },
      options: ['small', 'medium', 'large'],
    },
  },*/
} satisfies Meta<Footer>;

export default meta;
type Story = StoryObj<typeof meta>;

// More on writing stories with args: https://storybook.js.org/docs/writing-stories/args
export const Primary: Story = {
	args: {
		label: 'Join the taiko community',
		title: 'Taiko',
		text: 'The most developer-friendly and secure Ethereum scaling solution'
	}
};
