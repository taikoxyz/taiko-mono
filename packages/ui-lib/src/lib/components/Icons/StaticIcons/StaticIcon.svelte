<script lang="ts" context="module">
	import type { IconType } from './types';
</script>

<script lang="ts">
	import { iconPaths } from './paths';

	export let type: IconType;
	export let size = 20;
	export let width = size;
	export let height = size;
	export let fillClass = 'fill-primary-icon';
	export let vWidth = 20;
	export let vHeight = 20;

	$: viewBox = `0 0 ${vWidth} ${vHeight}`;
</script>

<svg
	{width}
	{height}
	class={$$props.class}
	{viewBox}
	fill="none"
	xmlns="http://www.w3.org/2000/svg"
>
	{#if iconPaths[type]}
		{@html iconPaths[type](fillClass)}
	{:else}
		<path d="M0 0h24v24H0z" />
	{/if}
</svg>
