<script lang="ts">
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import { Icon, type IconType } from '$components/Icon';
	import { signedBlocksPerGuardian } from '$lib/blocks/signedBlocksPerGuardian';
	import { lastGuardianFetchTimestamp, signedBlocks } from '$stores';
	import { GuardianProverStatus, type Guardian } from '$lib/types';
	import { truncateDecimal } from '$lib/util/truncateDecimal';
	import { truncateString } from '$lib/util/truncateString';
	import { onMount } from 'svelte';
	import { t } from 'svelte-i18n';
	import DataPoint from './DataPoint.svelte';

	export let guardianProver: Guardian;
	export let single = false;

	let isDesktopOrLarger: boolean;

	$: iconType =
		guardianProver.alive === GuardianProverStatus.ALIVE
			? ('check-circle' as IconType)
			: guardianProver.alive === GuardianProverStatus.DEAD
				? ('x-close-circle' as IconType)
				: guardianProver.alive === GuardianProverStatus.UNHEALTHY
					? ('exclamation-circle' as IconType)
					: ('x-close-circle' as IconType);

	$: fillClass =
		guardianProver.alive === GuardianProverStatus.ALIVE
			? 'fill-success-content'
			: guardianProver.alive === GuardianProverStatus.DEAD
				? 'fill-error-content'
				: guardianProver.alive === GuardianProverStatus.UNHEALTHY
					? 'fill-warning-sentiment'
					: 'fill-error-content';

	$: statusText =
		guardianProver.alive === GuardianProverStatus.ALIVE
			? $t('filter.guardian_status.alive')
			: guardianProver.alive === GuardianProverStatus.DEAD
				? $t('filter.guardian_status.dead')
				: guardianProver.alive === GuardianProverStatus.UNHEALTHY
					? $t('filter.guardian_status.unhealthy')
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

<div class="collapse collapse-plus bg-base-200">
	<input type="checkbox" id={`guardian-${guardianProver.id}`} class="peer" />
	{#if isDesktopOrLarger}
		<div class="collapse-title text-xl font-medium f-row items-center">
			<div class="f-row min-w-[150px]">
				<Icon type={iconType} {fillClass} class="min-w-[20px] min-h-[20px]" size={20} />
				<div class="f-col">
					<span class="font-bold">{statusText}</span>
					<span class="text-sm">{secondsAgo}s ago</span>
				</div>
			</div>

			<div class="f-col">
				<div class="font-bold">
					{guardianProver.name}
					<!-- {$t('common.prover')}
					{guardianProver.id} -->
				</div>
				<div class="text-secondary-content">{guardianProver.address}</div>
			</div>
		</div>
		<div class="collapse-content bg-grey-10">
			{#if single}
				<div class="col-span-2">
					{$t('overview.detail.table.uptime', {
						values: { uptime: truncateDecimal(guardianProver.uptime, 2) }
					})}
				</div>
			{:else}
				<div class="f-row">
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

					<DataPoint
						headline="L1 Node Version"
						dataPoint={guardianProver?.nodeInfo?.l1NodeVersion}
					/>
					<DataPoint
						headline="L2 Node Version"
						dataPoint={guardianProver?.nodeInfo?.l2NodeVersion}
					/>
					<DataPoint headline="Revision" dataPoint={guardianProver?.nodeInfo?.revision} />
					<DataPoint headline="Last restart" dataPoint={guardianProver?.lastRestart} />
				</div>
			{/if}
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
