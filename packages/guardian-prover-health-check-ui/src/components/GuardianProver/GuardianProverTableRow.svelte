<script lang="ts">
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import { Icon, type IconType } from '$components/Icon';
	import { signedBlocksPerGuardian } from '$lib/blocks/signedBlocksPerGuardian';
	import { guardianProvers, lastGuardianFetchTimestamp, signedBlocks } from '$lib/dataFetcher';
	import { GuardianProverStatus, type Guardian } from '$lib/types';
	import { truncateDecimal } from '$lib/util/truncateDecimal';
	import { truncateString } from '$lib/util/truncateString';
	import { onMount } from 'svelte';
	import { t } from 'svelte-i18n';

	export let guardianProver: Guardian;
	export let single = false;

	let isDesktopOrLarger: boolean;

	const getStatus = () => {
		const reportedStatus = guardianProver.alive;
		const signed = signedBlocksPerGuardian(guardianProver.id);

		if (reportedStatus === GuardianProverStatus.DEAD) {
			guardianProver.alive = GuardianProverStatus.DEAD;
		} else if (signed < $signedBlocks.length - 1) {
			// if at least two blocks were not signed, the prover is unhealthy
			guardianProver.alive = GuardianProverStatus.UNHEALTHY;
		} else {
			guardianProver.alive = GuardianProverStatus.ALIVE;
		}
	};

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

	$: if ($guardianProvers) getStatus();

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

	const classes =
		'grid grid-cols-12 bg-base-200 px-[24px] py-[16px] rounded-[20px] space-x-[18px] max-h-[76px] items-center';

	onMount(() => {
		getStatus();
		return () => clearInterval(interval);
	});
</script>

{#if isDesktopOrLarger}
	<div role="button" tabindex="0" class={classes} on:click on:keydown>
		<div class="col-span-1 f-row min-w-[100px] max-w-[100px] items-center">
			<Icon type={iconType} {fillClass} class="min-w-[20px] min-h-[20px]" size={20} />
			<div class="f-col ml-[15px]">
				<span class="font-bold">{statusText}</span>
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
				<span class="font-bold">{statusText}</span>
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
