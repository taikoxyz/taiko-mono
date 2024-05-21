<script>
	import { getContext } from 'svelte';
	const ctx = getContext('iconCtx') ?? {};
	let className = ctx.class || '';
	export { className as class };
	export let size = ctx.size || '24';
	export let role = ctx.role || 'img';
	export let color = ctx.color || 'currentColor';
	export let withEvents = ctx.withEvents || false;
	export let ariaLabel = 'menu';
	export let title = {
		id: `menu-title-${Math.random().toString(36).substring(7)}`,
		title: ariaLabel
	};
	export let desc = {
		id: `menu-desc-${Math.random().toString(36).substring(7)}`,
		desc: 'A menu icon'
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
		viewBox="0 0 15 8"
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

		<path d="M0.0390625 0.75H14.0391" stroke={color} stroke-width="1.2" />
		<path d="M0.0390625 7.25H14.0391" stroke={color} stroke-width="1.2" />
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
		viewBox="0 0 15 8"
	>
		{#if title.id && title.title}
			<title id={title.id}>{title.title}</title>
		{/if}
		{#if desc.id && desc.desc}
			<desc id={desc.id}>{desc.desc}</desc>
		{/if}

		<path d="M0.0390625 0.75H14.0391" stroke={color} stroke-width="1.2" />
		<path d="M0.0390625 7.25H14.0391" stroke={color} stroke-width="1.2" />
	</svg>
{/if}
