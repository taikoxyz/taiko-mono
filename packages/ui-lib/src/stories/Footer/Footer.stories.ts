import '../../app.css';
import type { Meta, StoryObj } from '@storybook/svelte';
import { Footer } from '../../lib/components/Footer';

// More on how to set up stories at: https://storybook.js.org/docs/writing-stories
const meta = {
	title: 'Footer',
	component: Footer
	//tags: ['autodocs'],
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
		label: 'Footer'
	}
};
