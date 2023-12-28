<script lang="ts">
	import { Icon } from '$components/Icon';
	import OverviewTableRow from '$components/Overview/OverviewTableRow.svelte';
	import StatusBanner from '$components/StatusBanner/StatusBanner.svelte';
	import Tabs from '$components/Tabs/Tabs.svelte';
	import { selectedGuardianProver } from '$components/stores/guardianProver';
</script>

<section id="header" class="f-row f-center-space-between justify-end">
	<img src="/taiko-logo.svg" alt="logo" class="w-[105px] h-[29px]" />

	<div class="ml-auto">
		<Tabs />
	</div>
</section>
{#if $selectedGuardianProver}
	<button on:click={() => ($selectedGuardianProver = null)} class="btn max-w-[48px] rounded-full">
		<Icon type="arrow-left" size={24} />
	</button>
{/if}
<section id="header-content" class="min-h-[76px] my-[30px]">
	{#if $selectedGuardianProver}
		<OverviewTableRow guardianProver={$selectedGuardianProver} small />
	{:else}
		<StatusBanner />
	{/if}
</section>
