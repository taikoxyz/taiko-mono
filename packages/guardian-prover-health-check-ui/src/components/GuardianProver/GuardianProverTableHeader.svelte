<script lang="ts">
	import { DesktopOrLarger } from '$components/DesktopOrLarger';
	import { t } from 'svelte-i18n';

	let isDesktopOrLarger: boolean;
</script>

<div class="mt-[40px]">
	{#if isDesktopOrLarger}
		<div class="grid grid-cols-12 py-2 pl-10 font-bold">
			<div class="col-span-1">{$t('overview.table.status')}</div>
			<div class="col-span-2"></div>
			<div class="col-span-6">{$t('overview.table.address')}</div>
			<div class="col-span-2">{$t('overview.table.balance')}</div>
			<div class="col-span-1">{$t('overview.table.no_blocks_created')}</div>
		</div>
	{/if}
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
