<script lang="ts">
	import { DesktopOrLarger } from '$components/DesktopOrLarger';

	export let headline: string;
	export let dataPoint: string;

	let isDesktopOrLarger = false;
</script>

{#if isDesktopOrLarger}
	<div class="f-col grow py-[16px]">
		<div class="font-bold">{headline}</div>
		<div>{dataPoint}</div>
	</div>
{:else}
	<div class="f-row justify-between w-full">
		<div class="font-bold">{headline}</div>
		<div class="text-right">{dataPoint}</div>
	</div>
{/if}

<DesktopOrLarger bind:is={isDesktopOrLarger} />
