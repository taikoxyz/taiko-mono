import { default as AngleDownSolid } from './AngleDownSolid.svelte';
import { default as AngleLeft } from './AngleLeft.svelte';
import { default as AngleRight } from './AngleRight.svelte';
import { default as ArrowDown } from './ArrowDown.svelte';
import { default as ArrowRightFilled } from './ArrowRightFilled.svelte';
import { default as CircleUserRegular } from './CircleUserRegular.svelte';
import { default as DiscordLogo } from './DiscordLogo.svelte';
import { default as Menu } from './Menu.svelte';
import { default as MinusSign } from './MinusSign.svelte';
import { default as MirrorLogo } from './MirrorLogo.svelte';
import { default as Moon } from './Moon.svelte';
import { default as PlusSign } from './PlusSign.svelte';
import { default as Sun } from './Sun.svelte';
import { default as TaikoLogo } from './TaikoLogo.svelte';
import { default as TwitterLogo } from './TwitterLogo.svelte';
import { default as UpRightArrow } from './UpRightArrow.svelte';
import { default as XSolid } from './XSolid.svelte';
import { default as YoutubeLogo } from './YoutubeLogo.svelte';

export const Icons = {
	CircleUserRegular,
	AngleDownSolid,
	Menu,
	ArrowDown,
	ArrowRightFilled,
	DiscordLogo,
	MinusSign,
	MirrorLogo,
	Moon,
	PlusSign,
	Sun,
	TaikoLogo,
	TwitterLogo,
	UpRightArrow,
	XSolid,
	YoutubeLogo,
	AngleLeft,
	AngleRight
};

export type IconType = keyof typeof Icons;
