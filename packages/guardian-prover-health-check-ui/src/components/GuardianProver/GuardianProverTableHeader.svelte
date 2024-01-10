<script lang="ts">
	import { DesktopOrLarger } from '$components/DesktopOrLarger';
	import { t } from 'svelte-i18n';

	let isDesktopOrLarger: boolean;
</script>

<div class="mt-[40px]">
	{#if isDesktopOrLarger}
		<div
			class="grid grid-cols-12 px-[24px] py-[16px] rounded-[20px] space-x-[18px] max-h-[76px] font-bold"
		>
			<div class="col-span-3">
				{$t('overview.table.status')}
			</div>
			<div class="col-span-6">{$t('overview.table.address')}</div>
			<div class="col-span-2">{$t('overview.table.balance')}</div>
			<div class="col-span-1">{$t('overview.table.no_blocks_created')}</div>
		</div>
	{/if}
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
