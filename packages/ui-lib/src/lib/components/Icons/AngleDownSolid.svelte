<script>
	import { getContext } from 'svelte';
	const ctx = getContext('iconCtx') ?? {};
	let className = ctx.class || '';
	export { className as class };
	export let size = ctx.size || '24';
	export let role = ctx.role || 'img';
	export let color = ctx.color || 'currentColor';
	export let withEvents = ctx.withEvents || false;
	export let ariaLabel = 'angle down solid';
	export let title = {
		id: `angle-down-solid-title-${Math.random().toString(36).substring(7)}`,
		title: ariaLabel
	};
	export let desc = {
		id: `angle-down-solid-desc-${Math.random().toString(36).substring(7)}`,
		desc: 'An angle down solid icon'
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
		fill={color}
		class={className}
		aria-label={ariaLabel}
		aria-describedby={hasDescription ? ariaDescribedby : undefined}
		viewBox="0 0 448 512"
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
			d="M201.4 342.6c12.5 12.5 32.8 12.5 45.3 0l160-160c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L224 274.7 86.6 137.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3l160 160z"
		/>
	</svg>
{:else}
	<svg
		xmlns="http://www.w3.org/2000/svg"
		{...$$restProps}
		{role}
		width={size}
		height={size}
		fill={color}
		class={className}
		aria-label={ariaLabel}
		aria-describedby={hasDescription ? ariaDescribedby : undefined}
		viewBox="0 0 448 512"
	>
		{#if title.id && title.title}
			<title id={title.id}>{title.title}</title>
		{/if}
		{#if desc.id && desc.desc}
			<desc id={desc.id}>{desc.desc}</desc>
		{/if}
		<path
			d="M201.4 342.6c12.5 12.5 32.8 12.5 45.3 0l160-160c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L224 274.7 86.6 137.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3l160 160z"
		/>
	</svg>
{/if}

<!--
    @component
    [Go to docs](https://svelte-awesome-icons.codewithshin.com)
    ## Props
    @prop export let size: string = ctx.size || '24';
    @prop export let role: string = ctx.role || 'img';
    @prop export let color: string = ctx.color || 'currentColor';
    @prop export let withEvents = ctx.withEvents || false;
    @prop export let ariaLabel: string = 'angle down solid';
    @prop export let title: TitleType = {};
    @prop export let desc: DescType = {};
    -->
