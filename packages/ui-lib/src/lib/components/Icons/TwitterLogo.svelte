<script>
	import { getContext } from 'svelte';
	const ctx = getContext('iconCtx') ?? {};
	let className = ctx.class || '';
	export { className as class };
	export let size = ctx.size || '24';
	export let role = ctx.role || 'img';
	export let color = ctx.color || 'currentColor';
	export let withEvents = ctx.withEvents || false;
	export let ariaLabel = 'twitter logo';
	export let title = {
		id: `twitter-logo-title-${Math.random().toString(36).substring(7)}`,
		title: ariaLabel
	};
	export let desc = {
		id: `twitter-logo-desc-${Math.random().toString(36).substring(7)}`,
		desc: 'A twitter logo icon'
	};
	let ariaDescribedby = `${title.id || ''} ${desc.id || ''}`;
	let hasDescription = false;
	$: if (title.id || desc.id) {
		hasDescription = true;
	} else {
		hasDescription = false;
	}
</script>

{#if withEvents}
	<svg
		xmlns="http://www.w3.org/2000/svg"
		{...$$restProps}
		{role}
		width={size}
		height={size}
		class={className}
		aria-label={ariaLabel}
		aria-describedby={hasDescription ? ariaDescribedby : undefined}
		viewBox="0 0 32 30"
		on:click
		on:keydown
		on:keyup
		on:focus
		on:blur
		on:mouseenter
		on:mouseleave
		on:mouseover
		on:mouseout
	>
		{#if title.id && title.title}
			<title id={title.id}>{title.title}</title>
		{/if}
		{#if desc.id && desc.desc}
			<desc id={desc.id}>{desc.desc}</desc>
		{/if}

		<path
			d="M25.2624 0.972656H30.0415L19.6006 12.9059L31.8835 29.1444H22.266L14.7333 19.2959L6.11422 29.1444H1.33224L12.4998 16.3805L0.716797 0.972656H10.5784L17.3873 9.97463L25.2624 0.972656ZM23.5851 26.2839H26.2332L9.13944 3.68293H6.2977L23.5851 26.2839Z"
			fill={color}
		/>
	</svg>
{:else}
	<svg
		xmlns="http://www.w3.org/2000/svg"
		{...$$restProps}
		{role}
		width={size}
		height={size}
		class={className}
		aria-label={ariaLabel}
		aria-describedby={hasDescription ? ariaDescribedby : undefined}
		viewBox="0 0 32 30"
	>
		{#if title.id && title.title}
			<title id={title.id}>{title.title}</title>
		{/if}
		{#if desc.id && desc.desc}
			<desc id={desc.id}>{desc.desc}</desc>
		{/if}

		<path
			d="M25.2624 0.972656H30.0415L19.6006 12.9059L31.8835 29.1444H22.266L14.7333 19.2959L6.11422 29.1444H1.33224L12.4998 16.3805L0.716797 0.972656H10.5784L17.3873 9.97463L25.2624 0.972656ZM23.5851 26.2839H26.2332L9.13944 3.68293H6.2977L23.5851 26.2839Z"
			fill={color}
		/>
	</svg>
{/if}
