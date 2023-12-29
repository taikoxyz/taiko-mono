<script lang="ts">
	import { t } from 'svelte-i18n';
</script>

<div class="grid grid-cols-12 py-2 pl-10 font-bold mt-[40px]">
	<div class="col-span-1">{$t('overview.table.status')}</div>
	<div class="col-span-2"></div>
	<div class="col-span-6">{$t('overview.table.address')}</div>
	<div class="col-span-2">{$t('overview.table.balance')}</div>
	<div class="col-span-1">{$t('overview.table.no_blocks_created')}</div>
</div>
