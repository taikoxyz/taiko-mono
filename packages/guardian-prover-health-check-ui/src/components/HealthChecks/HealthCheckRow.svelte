<script lang="ts">
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import Icon from '$components/Icon/Icon.svelte';
	import type { HealthCheck } from '$lib/types';
	import { classNames } from '$lib/util/classNames';
	import { truncateString } from '$lib/util/truncateString';
	import { t } from 'svelte-i18n';

	export let healthCheck: HealthCheck;

	let isDesktopOrLarger: boolean;

	$: colClasses = classNames(
		'py-[18px] border-b border-gray-300 ',
		isDesktopOrLarger ? 'h-[56px]' : 'h-[100px]'
	);
</script>

{#if isDesktopOrLarger}
	<div class={classNames('col-span-1', colClasses)}>
		<p class="f-row text-gray-900">
			{#if healthCheck.alive}
				<Icon type="check" fillClass="fill-positive-sentiment" size={24} />
				{$t('filter.guardian_status.alive')}
			{:else}
				<Icon type="x-close" fillClass="fill-negative-sentiment" size={24} />
				{$t('filter.guardian_status.dead')}
			{/if}
		</p>
	</div>

	<div class={classNames('col-span-5 content-center flex flex-wrap', colClasses)}>
		<p class="text-gray-900">
			{healthCheck.expectedAddress}
		</p>
	</div>
	<div class={classNames('col-span-4 content-center flex flex-wrap', colClasses)}>
		<p class="text-gray-900">
			{healthCheck.recoveredAddress}
		</p>
	</div>
	<div class={classNames('col-span-2 flex content-center flex-wrap', colClasses)}>
		<div class="flex flex-col items-center">
			<p class="text-gray-900">
				{new Date(healthCheck.createdAt).toLocaleDateString()}
			</p>
			<p class="text-gray-900">
				{new Date(healthCheck.createdAt).toLocaleTimeString()}
			</p>
		</div>
	</div>
{:else}
	<div class={classNames('col-span-3 flex content-center flex-wrap ', colClasses)}>
		<p class="f-col text-gray-900 items-center">
			{#if healthCheck.alive}
				<Icon type="check" fillClass="fill-positive-sentiment" size={24} />
				{$t('filter.guardian_status.alive')}
			{:else}
				<Icon type="x-close" fillClass="fill-negative-sentiment" size={24} />
				{$t('filter.guardian_status.dead')}
			{/if}
		</p>
	</div>
	<div class={classNames('col-span-6', colClasses)}>
		<div class="f-col text-sm">
			<p class="text-gray-900 f-col">
				<span class="text-tertiary-content">Expected</span>
				{truncateString(healthCheck.expectedAddress, 14)}
			</p>
			<p class="text-gray-900 f-col">
				<span class="text-tertiary-content">Recovered</span>
				{truncateString(healthCheck.recoveredAddress, 14)}
			</p>
		</div>
	</div>
	<div class={classNames('col-span-3 flex content-center flex-wrap mt-0', colClasses)}>
		<div class="flex flex-col">
			<p class="text-gray-900">
				{new Date(healthCheck.createdAt).toLocaleDateString()}
			</p>
			<p class="text-gray-900">
				{new Date(healthCheck.createdAt).toLocaleTimeString()}
			</p>
		</div>
	</div>
{/if}

<DesktopOrLarger bind:is={isDesktopOrLarger} />
