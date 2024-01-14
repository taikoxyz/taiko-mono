<script lang="ts">
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { GuardianProverTableRow } from '$components/GuardianProver';
	import StatusBanner from '$components/StatusBanner/StatusBanner.svelte';
	import Tabs from '$components/Tabs/Tabs.svelte';
	import { selectedGuardianProver } from '$stores';

	$: displayDetails = $selectedGuardianProver && $page.route.id === '/[slug]';
</script>

<section id="header" class="f-row f-center-space-between justify-end">
	<div
		class="cursor-pointer"
		role="button"
		tabindex="0"
		on:click={() => goto('/')}
		on:keydown={() => goto('/')}
	>
		<img src="/taiko-logo.svg" alt="logo" class="w-[105px] h-[29px]" />
	</div>

	<div class="ml-auto">
		<Tabs />
	</div>
</section>
<section id="header-content" class="min-h-[76px] my-[30px]">
	{#if displayDetails}
		<GuardianProverTableRow guardianProver={$selectedGuardianProver} single />
	{:else}
		<StatusBanner />
	{/if}
</section>
