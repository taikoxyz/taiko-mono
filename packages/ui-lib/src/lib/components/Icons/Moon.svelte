<script>
	import { getContext } from 'svelte';
	const ctx = getContext('iconCtx') ?? {};
	let className = ctx.class || '';
	export { className as class };
	export let size = ctx.size || '24';
	export let role = ctx.role || 'img';
	export let color = ctx.color || 'currentColor';
	export let withEvents = ctx.withEvents || false;
	export let ariaLabel = 'moon';
	export let title = {
		id: `moon-title-${Math.random().toString(36).substring(7)}`,
		title: ariaLabel
	};
	export let desc = {
		id: `moon-desc-${Math.random().toString(36).substring(7)}`,
		desc: 'A moon icon'
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
		viewBox="0 0 21 21"
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
			d="M7.52839 0.717861C7.74339 0.932863 7.80731 1.2564 7.69021 1.53701C7.2458 2.60204 7 3.77143 7 5.00013C7 9.9707 11.0294 14.0001 16 14.0001C17.2287 14.0001 18.3981 13.7543 19.4631 13.3099C19.7437 13.1928 20.0673 13.2567 20.2823 13.4717C20.4973 13.6867 20.5612 14.0103 20.4441 14.2909C18.8618 18.0828 15.1183 20.7501 10.75 20.7501C4.95101 20.7501 0.25 16.0491 0.25 10.2501C0.25 5.88184 2.91735 2.13829 6.70924 0.556033C6.98985 0.438941 7.31338 0.502858 7.52839 0.717861Z"
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
		viewBox="0 0 21 21"
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
			d="M7.52839 0.717861C7.74339 0.932863 7.80731 1.2564 7.69021 1.53701C7.2458 2.60204 7 3.77143 7 5.00013C7 9.9707 11.0294 14.0001 16 14.0001C17.2287 14.0001 18.3981 13.7543 19.4631 13.3099C19.7437 13.1928 20.0673 13.2567 20.2823 13.4717C20.4973 13.6867 20.5612 14.0103 20.4441 14.2909C18.8618 18.0828 15.1183 20.7501 10.75 20.7501C4.95101 20.7501 0.25 16.0491 0.25 10.2501C0.25 5.88184 2.91735 2.13829 6.70924 0.556033C6.98985 0.438941 7.31338 0.502858 7.52839 0.717861Z"
			fill={color}
		/>
	</svg>
{/if}
