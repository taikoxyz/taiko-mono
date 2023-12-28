<script lang="ts">
	import Icon from '$components/Icon/Icon.svelte';
	import type { HealthCheck } from '$lib/types';
	import { classNames } from '$lib/util/classNames';

	export let healthCheck: HealthCheck;

	const colClasses = 'my-[9px] border-b border-gray-300 h-[42px]';
</script>

<div class={classNames('col-span-1', colClasses)}>
	<p class="f-row text-gray-900 whitespace-no-wrap">
		{#if healthCheck.alive}
			<Icon type="check" fillClass="fill-positive-sentiment" size={24} /> True
		{:else}
			<Icon type="x-close" fillClass="fill-negative-sentiment" size={24} /> False
		{/if}
	</p>
</div>
<!-- <div class={classNames('col-span-1', colClasses)}>
	<p class="text-gray-900 whitespace-no-wrap">fake 100%</p>
</div> -->
<div class={classNames('col-span-5', colClasses)}>
	<p class="text-gray-900 whitespace-no-wrap">{healthCheck.expectedAddress}</p>
</div>
<div class={classNames('col-span-4', colClasses)}>
	<p class="text-gray-900 whitespace-no-wrap">{healthCheck.recoveredAddress}</p>
</div>
<div class={classNames('col-span-2', colClasses)}>
	<p class="text-gray-900 whitespace-no-wrap">
		{new Date(healthCheck.createdAt).toLocaleString()}
	</p>
</div>
