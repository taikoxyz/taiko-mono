<script>
	import { getContext } from 'svelte';
	const ctx = getContext('iconCtx') ?? {};
	let className = ctx.class || '';
	export { className as class };
	export let size = ctx.size || '24';
	export let role = ctx.role || 'img';
	export let color = ctx.color || 'currentColor';
	export let withEvents = ctx.withEvents || false;
	export let ariaLabel = 'up right arrow';
	export let title = {
		id: `up-right-arrow-title-${Math.random().toString(36).substring(7)}`,
		title: ariaLabel
	};
	export let desc = {
		id: `up-right-arrow-desc-${Math.random().toString(36).substring(7)}`,
		desc: 'An up right arrow icon'
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
		viewBox="0 0 10 10"
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
			fill-rule="evenodd"
			clip-rule="evenodd"
			d="M0.21967 9.78033C0.512563 10.0732 0.987437 10.0732 1.28033 9.78033L8.5 2.56066V8.25C8.5 8.66421 8.83579 9 9.25 9C9.66421 9 10 8.66421 10 8.25V0.75C10 0.335787 9.66421 0 9.25 0H1.75C1.33579 0 1 0.335787 1 0.75C1 1.16421 1.33579 1.5 1.75 1.5H7.43934L0.21967 8.71967C-0.0732233 9.01256 -0.0732233 9.48744 0.21967 9.78033Z"
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
		viewBox="0 0 10 10"
	>
		{#if title.id && title.title}
			<title id={title.id}>{title.title}</title>
		{/if}
		{#if desc.id && desc.desc}
			<desc id={desc.id}>{desc.desc}</desc>
		{/if}

		<path
			fill-rule="evenodd"
			clip-rule="evenodd"
			d="M0.21967 9.78033C0.512563 10.0732 0.987437 10.0732 1.28033 9.78033L8.5 2.56066V8.25C8.5 8.66421 8.83579 9 9.25 9C9.66421 9 10 8.66421 10 8.25V0.75C10 0.335787 9.66421 0 9.25 0H1.75C1.33579 0 1 0.335787 1 0.75C1 1.16421 1.33579 1.5 1.75 1.5H7.43934L0.21967 8.71967C-0.0732233 9.01256 -0.0732233 9.48744 0.21967 9.78033Z"
			fill={color}
		/>
	</svg>
{/if}
