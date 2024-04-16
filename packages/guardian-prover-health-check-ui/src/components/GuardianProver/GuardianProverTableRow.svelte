<script lang="ts">
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import { Icon, type IconType } from '$components/Icon';
	import { signedBlocksPerGuardian } from '$lib/blocks/signedBlocksPerGuardian';
	import { lastGuardianFetchTimestamp, loading, signedBlocks } from '$stores';
	import { GuardianProverStatus, type Guardian } from '$lib/types';
	import { truncateDecimal } from '$lib/util/truncateDecimal';
	import { truncateString } from '$lib/util/truncateString';
	import { onMount } from 'svelte';
	import { t } from 'svelte-i18n';
	import DataPoint from './DataPoint.svelte';
	import IconFlipper from '$components/Icon/IconFlipper.svelte';
	import { formatISODateTime } from '$lib/util/formatISODateTime';
	import { Spinner } from '$components/Spinner';

	export let guardianProver: Guardian;
	export let single = false;

	let flipped = false;

	let isDesktopOrLarger: boolean;

	$: iconType =
		guardianProver.alive === GuardianProverStatus.ALIVE
			? ('check-circle' as IconType)
			: guardianProver.alive === GuardianProverStatus.DEAD
				? ('x-close-circle' as IconType)
				: guardianProver.alive === GuardianProverStatus.UNHEALTHY
					? ('exclamation-circle' as IconType)
					: guardianProver.alive === GuardianProverStatus.UNKNOWN
						? ('question-circle' as IconType)
						: ('x-close-circle' as IconType);

	$: fillClass =
		guardianProver.alive === GuardianProverStatus.ALIVE
			? 'fill-success-content'
			: guardianProver.alive === GuardianProverStatus.DEAD
				? 'fill-error-content'
				: guardianProver.alive === GuardianProverStatus.UNHEALTHY
					? 'fill-warning-sentiment'
					: guardianProver.alive === GuardianProverStatus.UNKNOWN
						? 'fill-neutral-content'
						: 'fill-error-content';

	$: statusText =
		guardianProver.alive === GuardianProverStatus.ALIVE
			? $t('filter.guardian_status.alive')
			: guardianProver.alive === GuardianProverStatus.DEAD
				? $t('filter.guardian_status.dead')
				: guardianProver.alive === GuardianProverStatus.UNHEALTHY
					? $t('filter.guardian_status.unhealthy')
					: guardianProver.alive === GuardianProverStatus.UNKNOWN
						? $t('filter.guardian_status.unknown')
						: $t('filter.guardian_status.dead');

	$: secondsAgo = Math.floor((Date.now() - $lastGuardianFetchTimestamp) / 1000);

	// add 1 second every second to secondsAgo
	const interval = setInterval(() => {
		secondsAgo += 1;
	}, 1000);

	onMount(() => {
		return () => clearInterval(interval);
	});
</script>

<div
	class="collapse
	{single ? 'collapse-open' : ''} 
	{$loading ? 'collapse-close' : ''}
	bg-base-200"
>
	<input type="checkbox" id={`guardian-${guardianProver.id}`} class="peer" bind:checked={flipped} />
	{#if isDesktopOrLarger}
		<div class="collapse-title text-xl font-medium f-row">
			<div class="f-row min-w-[150px] items-center gap-4">
				{#if $loading}
					<Icon
						type="question-circle"
						fillClass="fill-neutral-content"
						class="min-w-[20px] min-h-[20px]"
						size={20}
					/>
					<Spinner class="w-4 h-4" />
				{:else}
					<Icon type={iconType} {fillClass} class="min-w-[20px] min-h-[20px]" size={20} />
					<div class="f-col">
						<span class="font-bold">{statusText}</span>
						<span class="text-sm">{secondsAgo}s ago</span>
					</div>
				{/if}
			</div>

			<div class="f-col grow">
				<div class="font-bold">
					{guardianProver.name}
				</div>
				<div class="text-secondary-content">{guardianProver.address}</div>
			</div>
			{#if !single && !$loading}
				<IconFlipper
					bind:flipped
					iconType1="chevron-left"
					iconType2="chevron-down"
					selectedDefault="chevron-left"
					size={15}
					noEvent
				/>
			{/if}
		</div>
		<div class="collapse-content bg-grey-10">
			<div class="f-row items-center">
				<div class="min-w-[150px]" />

				<DataPoint
					headline={$t('overview.table.balance')}
					dataPoint={truncateDecimal(Number(guardianProver.balance), 3).toString() + ' ETH'}
				/>

				<DataPoint
					headline={$t('overview.detail.table.uptime')}
					dataPoint={truncateDecimal(guardianProver.uptime, 2).toString() + '%'}
				/>

				<DataPoint
					headline={$t('overview.table.no_blocks_created')}
					dataPoint="{signedBlocksPerGuardian(guardianProver.id)}/{$signedBlocks.length}"
				/>

				<DataPoint headline="L1 Node Version" dataPoint={guardianProver?.nodeInfo?.l1NodeVersion} />
				<DataPoint headline="L2 Node Version" dataPoint={guardianProver?.nodeInfo?.l2NodeVersion} />
				<DataPoint headline="Revision" dataPoint={guardianProver?.nodeInfo?.revision} />
				<DataPoint
					headline="Last restart"
					dataPoint={formatISODateTime(guardianProver?.lastRestart)}
				/>

				{#if !single}
					<button class="link" on:click>{$t('overview.table.view_details')}</button>
				{/if}
			</div>
		</div>
	{:else}
		<div class="col-span-4 f-row min-w-[150px] items-center">
			<Icon type={iconType} {fillClass} />
			<div class="f-col ml-[15px]">
				<span class="font-bold">{statusText}</span>
				<span class="text-sm">{secondsAgo}s ago</span>
			</div>
		</div>
		<div class="col-span-8 font-bold">
			<div class="f-col">
				<span class="font-bold"
					>{$t('common.prover')}
					{guardianProver.id}</span
				>
				<span class="font-normal">{truncateString(guardianProver.address, 10)}</span>
			</div>
		</div>
	{/if}
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
