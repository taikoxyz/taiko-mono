<script lang="ts">
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import { Icon } from '$components/Icon';
	import { signedBlocksPerGuardian } from '$lib/blocks/signedBlocksPerGuardian';
	import { lastGuardianFetchTimestamp, signedBlocks } from '$lib/dataFetcher';
	import type { Guardian } from '$lib/types';
	import { truncateDecimal } from '$lib/util/truncateDecimal';
	import { truncateString } from '$lib/util/truncateString';
	import { onMount } from 'svelte';
	import { t } from 'svelte-i18n';

	export let guardianProver: Guardian;
	export let single = false;

	let isDesktopOrLarger: boolean;

	const iconType = guardianProver.alive ? 'check-circle' : 'x-close-circle';

	const fillClass = guardianProver.alive ? 'fill-success-content' : 'fill-error-content';

	$: status = guardianProver.alive
		? $t('filter.guardian_status.alive')
		: $t('filter.guardian_status.dead');

	$: secondsAgo = Math.floor((Date.now() - $lastGuardianFetchTimestamp) / 1000);

	// add 1 second every second to secondsAgo
	const interval = setInterval(() => {
		secondsAgo += 1;
	}, 1000);

	const classes =
		'grid grid-cols-12 bg-base-200 px-[24px] py-[16px] rounded-[20px] space-x-[18px] max-h-[76px] items-center';

	onMount(() => {
		return () => clearInterval(interval);
	});
</script>

{#if isDesktopOrLarger}
	<div role="button" tabindex="0" class={classes} on:click on:keydown>
		<div class="col-span-1 f-row min-w-[100px] max-w-[100px] items-center">
			<Icon type={iconType} {fillClass} />
			<div class="f-col ml-[15px]">
				<span class="font-bold">{status}</span>
				<span class="text-sm">{secondsAgo}s ago</span>
			</div>
		</div>
		<div class="col-span-2 font-bold min-w-[150px] max-w-[150px]">
			{$t('common.prover')}
			{guardianProver.id}
		</div>
		<div class="col-span-6">{guardianProver.address}</div>
		{#if !single}
			<div class="col-span-2">{truncateDecimal(Number(guardianProver.balance), 3)} ETH</div>
			<div class="col-span-1">
				{signedBlocksPerGuardian(guardianProver.id)}/{$signedBlocks.length}
			</div>
		{:else}
			<div class="col-span-2">
				{$t('overview.detail.table.uptime', {
					values: { uptime: truncateDecimal(guardianProver.uptime, 2) }
				})}
			</div>
		{/if}
	</div>
{:else}
	<div role="button" tabindex="0" class={classes} on:click on:keydown>
		<div class="col-span-3 f-row min-w-[150px] items-center">
			<Icon type={iconType} {fillClass} />
			<div class="f-col ml-[15px]">
				<span class="font-bold">{status}</span>
				<span class="text-sm">{secondsAgo}s ago</span>
			</div>
		</div>
		<div class="col-span-9 font-bold">
			<div class="f-col">
				<span class="font-bold"
					>{$t('common.prover')}
					{guardianProver.id}</span
				>
				<span class="font-normal">{truncateString(guardianProver.address, 10)}</span>
			</div>
		</div>
	</div>
{/if}

<DesktopOrLarger bind:is={isDesktopOrLarger} />
