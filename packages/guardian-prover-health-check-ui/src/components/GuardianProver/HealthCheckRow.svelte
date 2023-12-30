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
		'my-[9px] border-b border-gray-300 ',
		isDesktopOrLarger ? 'h-[42px]' : 'h-[100px]'
	);
</script>

{#if isDesktopOrLarger}
	<div class={classNames('col-span-1', colClasses)}>
		<p class="f-row text-gray-900 whitespace-no-wrap">
			{#if healthCheck.alive}
				<Icon type="check" fillClass="fill-positive-sentiment" size={24} />
				{$t('filter.guardian_status.alive')}
			{:else}
				<Icon type="x-close" fillClass="fill-negative-sentiment" size={24} />
				{$t('filter.guardian_status.dead')}
			{/if}
		</p>
	</div>

	<div class={classNames('col-span-5', colClasses)}>
		<p class="text-gray-900 whitespace-no-wrap">
			{healthCheck.expectedAddress}
		</p>
	</div>
	<div class={classNames('col-span-4', colClasses)}>
		<p class="text-gray-900 whitespace-no-wrap">
			{healthCheck.recoveredAddress}
		</p>
	</div>
	<div class={classNames('col-span-2', colClasses)}>
		<p class="text-gray-900 whitespace-no-wrap">
			{new Date(healthCheck.createdAt).toLocaleString()}
		</p>
	</div>
{:else}
	<div class={classNames('col-span-3', colClasses)}>
		<p class="f-col text-gray-900 whitespace-no-wrap">
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
			<p class="text-gray-900 whitespace-no-wrap f-col">
				<span class="text-tertiary-content">Expected</span>
				{truncateString(healthCheck.expectedAddress, 14)}
			</p>
			<p class="text-gray-900 whitespace-no-wrap f-col">
				<span class="text-tertiary-content">Recovered</span>
				{truncateString(healthCheck.recoveredAddress, 14)}
			</p>
		</div>
	</div>
	<div class={classNames('col-span-3', colClasses)}>
		<p class="text-gray-900 whitespace-no-wrap">
			{new Date(healthCheck.createdAt).toLocaleString()}
		</p>
	</div>
{/if}

<DesktopOrLarger bind:is={isDesktopOrLarger} />
