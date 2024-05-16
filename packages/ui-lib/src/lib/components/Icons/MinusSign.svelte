<script>
	import { getContext } from 'svelte';
	const ctx = getContext('iconCtx') ?? {};
	let className = ctx.class || '';
	export { className as class };
	export let size = ctx.size || '24';
	export let role = ctx.role || 'img';
	export let color = ctx.color || 'currentColor';
	export let withEvents = ctx.withEvents || false;
	export let ariaLabel = 'minus sign';
	export let title = {
		id: `minus-sign-title-${Math.random().toString(36).substring(7)}`,
		title: ariaLabel
	};
	export let desc = {
		id: `minus-sign-desc-${Math.random().toString(36).substring(7)}`,
		desc: 'A minus sign icon'
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
		viewBox="0 0 16 2"
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
			d="M0.302612 1C0.302612 0.585786 0.638399 0.25 1.05261 0.25H15.0526C15.4668 0.25 15.8026 0.585786 15.8026 1C15.8026 1.41421 15.4668 1.75 15.0526 1.75H1.05261C0.638399 1.75 0.302612 1.41421 0.302612 1Z"
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
		viewBox="0 0 16 2"
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
			d="M0.302612 1C0.302612 0.585786 0.638399 0.25 1.05261 0.25H15.0526C15.4668 0.25 15.8026 0.585786 15.8026 1C15.8026 1.41421 15.4668 1.75 15.0526 1.75H1.05261C0.638399 1.75 0.302612 1.41421 0.302612 1Z"
			fill={color}
		/>
	</svg>
{/if}
