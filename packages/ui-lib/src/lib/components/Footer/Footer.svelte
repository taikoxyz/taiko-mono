<script lang="ts">
	import { Copyright } from '../Copyright';
	import { Icons } from '../Icons';
	import { ResponsiveController } from '../ResponsiveController';
	import { classNames } from '$lib/util/classNames';

	import type { IconType } from '../Icons';
	let windowSize: 'sm' | 'md' | 'lg' = 'md';

	export let label: string = 'Join the taiko community';
	export let title: string = 'Taiko';
	export let text: string = 'The most developer-friendly and secure Ethereum scaling solution';

	export let socialLinks: {
		label: string;
		href: string;
		icon: IconType;
	}[] = [
		{
			icon: 'DiscordLogo',
			label: 'discord',
			href: 'https://discord.com/invite/taikoxyz'
		},
		{
			icon: 'TwitterLogo',
			label: 'twitter',
			href: 'https://twitter.com/taikoxyz'
		},
		{
			icon: 'MirrorLogo',
			label: 'mirror',
			href: 'https://taiko.mirror.xyz/'
		},
		{
			icon: 'TaikoLogo',
			label: 'forum',
			href: 'https://community.taiko.xyz/'
		},
		{
			icon: 'YoutubeLogo',
			label: 'youtube',
			href: 'https://www.youtube.com/@taikoxyz'
		}
	];

	export let textLinks: {
		title: string;
		list: {
			name: string;
			url: string;
		}[];
	}[] = [
		{
			title: 'About',
			list: [
				{
					name: 'Blog',
					url: '/blog'
				},
				{
					name: 'Careers',
					url: '/careers'
				},
				{
					name: 'Brand kit',
					url: '/brand-assets'
				}
			]
		},
		{
			title: 'Developers',
			list: [
				{
					name: 'Get started',
					url: 'https://docs.taiko.xyz/start-here/getting-started'
				},
				{
					name: 'GitHub',
					url: 'https://github.com/taikoxyz'
				}
			]
		},
		{
			title: 'Solutions',
			list: [
				{
					name: 'Bridge',
					url: 'https://bridge.hekla.taiko.xyz/'
				},
				{
					name: 'Swap',
					url: 'https://swap.hekla.taiko.xyz/'
				},
				{
					name: 'Documentation',
					url: 'https://docs.taiko.xyz/'
				},
				{
					name: 'Explorer',
					url: 'https://hekla.taikoscan.network/'
				}
			]
		}
	];

	$: hoveredIcon = 'none';
	const sectionClasses = classNames('justify-end align-end', 'mb-5');
	const sectionWrapperClasses = classNames(
		'w-full',
		'flex flex-col',
		'items-center',
		'justify-center',
		'bg-background-elevated',
		//'bg-primary',
		'mt-5',
		'p-5',
		'rounded-2xl',
		'md:gap-5',
		'gap-10'
	);

	const joinTaikoClasses = classNames(
		'w-full',
		'flex',
		'flex-row',
		'items-center',
		'justify-center',
		'uppercase',
		'gap-5',
		'text-[12px]/[17.46px]',
		'font-bold',
		'font-sans',
		'text-content-primary'
	);
	const socialLinksWrapperClasses = classNames(
		'w-full',
		'flex',
		'flex-row',
		'items-center',
		'justify-center',
		'gap-5'
	);

	const socialLinkClasses = classNames(
		'w-1/5',
		'flex flex-row',
		'items-center',
		'justify-center',
		'bg-background-neutral',
		'lg:p-5',
		'p-3',
		'gap-3',
		'rounded-xl',
		'text-content-primary',
		'font-medium',
		'lg:text-2xl',
		'md:text-base',
		'font-clash-grotesk',
		'border',
		'transition-all',
		'border-transparent',
		'hover:border-primary'
	);

	const bottomRowClasses = classNames(
		'w-full',
		'flex',
		'md:flex-row',
		'flex-col-reverse',
		'items-center',
		'justify-center',
		'gap-5'
	);

	const bottomLeftColClasses = classNames(
		'md:w-1/5',
		'h-full',
		'flex flex-col',
		'items-start',
		'justify-center',
		'gap-5',
		'my-5',
		'md:my-0',
		'w-full'
	);

	const bottomTitleClasses = classNames(
		'text-4xl',
		'font-clash-grotesk',
		'font-medium',
		'text-content-primary',
		'md:text-left',
		'text-center',
		'w-full'
	);

	const bottomContentClasses = classNames(
		'text-content-secondary',
		'font-sans',
		'text-base',
		'font-normal',
		'md:text-left',
		'w-full',
		'text-center'
	);

	const copyrightSmClasses = classNames(
		'w-full',
		'flex flex-row',
		'items-center',
		'justify-center',
		'gap-5',
		'px-5',
		'pt-6',
		'font-sans',
		'text-base',
		'text-content-secondary',
		'font-normal'
	);

	const textLinksWrapperClasses = classNames(
		'w-full',
		'flex flex-col',
		'items-center',
		'justify-center',
		'bg-background-neutral',
		'rounded-3xl',
		'p-7'
	);

	const textLinksRowClasses = classNames(
		'w-full',
		'h-full',
		'flex',
		'md:flex-row',
		'flex-col',
		'items-start',
		'justify-start',
		'gap-7',
		'px-5',
		'py-3'
	);

	const textLinksUlClasses = classNames(
		'w-1/5',
		'flex flex-col',
		'items-start',
		'justify-start',
		'md:gap-6',
		'gap-4',
		'text-base',
		'w-full'
	);

	const textLinkTitleClasses = classNames(
		'font-bold',
		'text-content-primary',
		'text-base',
		'uppercase'
	);

	const textLinkContentClasses = classNames(
		'hover:text-primary',
		'text-content-secondary',
		'text-base',
		'cursor-pointer'
	);

	const copyrightMdClasses = classNames(
		'w-full',
		'flex flex-row',
		'items-center',
		'justify-end',
		'gap-5',
		'px-5',
		'py-3',
		'font-sans',
		'text-base',
		'text-content-secondary',
		'font-normal'
	);
</script>

<div class={sectionClasses}>
	<div class={sectionWrapperClasses}>
		<div class={joinTaikoClasses}>
			{label}
		</div>
		<div class={socialLinksWrapperClasses}>
			{#each socialLinks as link}
				{@const Icon = Icons[link.icon]}
				<a
					on:mouseenter={() => (hoveredIcon = link.label)}
					on:mouseleave={() => (hoveredIcon = 'none')}
					href={link.href}
					target="_blank"
					class={socialLinkClasses}
				>
					<Icon
						size="28"
						class={classNames(
							'transition-colors',

							hoveredIcon === link.label && hoveredIcon === 'youtube'
								? 'text-red-500'
								: 'text-content-tertiary',
							hoveredIcon === link.label && hoveredIcon === 'forum'
								? 'text-primary'
								: 'text-content-tertiary',
							hoveredIcon === link.label && hoveredIcon === 'discord'
								? 'text-discord-purple'
								: 'text-content-tertiary',
							hoveredIcon === link.label && hoveredIcon === 'twitter'
								? 'text-icon-primary'
								: 'text-content-tertiary',
							hoveredIcon === link.label && hoveredIcon === 'mirror'
								? 'text-icon-primary'
								: 'text-content-tertiary'
						)}
					/>
					{#if windowSize !== 'sm'}
						{link.label}
					{/if}
				</a>
			{/each}
		</div>

		<div class={bottomRowClasses}>
			<div class={bottomLeftColClasses}>
				<div class={bottomTitleClasses}>
					{title}
				</div>
				<div class={bottomContentClasses}>
					{text}
				</div>

				{#if windowSize === 'sm'}
					<Copyright class={copyrightSmClasses} />{/if}
			</div>

			<div class={textLinksWrapperClasses}>
				<div class={textLinksRowClasses}>
					{#each textLinks as textLink}
						<ul class={textLinksUlClasses}>
							<li class={textLinkTitleClasses}>
								{textLink.title}
							</li>
							{#each textLink.list as link}
								<li class={textLinkContentClasses}>
									<a href={link.url}>{link.name}</a>
								</li>
							{/each}
						</ul>
					{/each}
				</div>
				{#if windowSize !== 'sm'}
					<Copyright class={copyrightMdClasses} />
				{/if}
			</div>
		</div>
	</div>
</div>

<ResponsiveController bind:windowSize />
