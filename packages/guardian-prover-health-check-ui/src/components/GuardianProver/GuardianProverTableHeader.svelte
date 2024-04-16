<script lang="ts">
	import { DesktopOrLarger } from '$components/DesktopOrLarger';
	import { t } from 'svelte-i18n';

	let isDesktopOrLarger: boolean;
</script>

<div class="mt-[40px]">
	{#if isDesktopOrLarger}
		<div class="flex rounded-[20px] space-x-[18px] max-h-[76px] font-bold p-4">
			<div class="min-w-[135px]">
				{$t('overview.table.status')}
			</div>
			<div class="">{$t('overview.table.address')}</div>
		</div>
	{/if}
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
