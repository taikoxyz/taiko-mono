<script lang="ts">
	import { Icon } from '$components/Icon';
	import OverviewTableRow from '$components/Overview/OverviewTableRow.svelte';
	import StatusBanner from '$components/StatusBanner/StatusBanner.svelte';
	import Tabs from '$components/Tabs/Tabs.svelte';
	import { selectedGuardianProver } from '$components/stores/guardianProver';
	import { selectedTab } from '$components/stores/pageTabs';
	import { PageTabs } from '$lib/types';
</script>

<section id="header" class="f-row f-center-space-between justify-end">
	<img src="/taiko-logo.svg" alt="logo" class="w-[105px] h-[29px]" />

	<div class="ml-auto">
		<Tabs />
	</div>
</section>
<section id="header-content" class="min-h-[76px] my-[30px]">
	{#if $selectedGuardianProver}
		<OverviewTableRow guardianProver={$selectedGuardianProver} small />
	{:else}
		<StatusBanner />
	{/if}
</section>
