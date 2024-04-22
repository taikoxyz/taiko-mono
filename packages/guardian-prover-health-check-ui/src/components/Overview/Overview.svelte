<script lang="ts">
	import { onMount } from 'svelte';
	import type { Guardian } from '$lib/types';
	import { GuardianProverTableHeader, GuardianProverTableRow } from '../GuardianProver/';
	import { selectedGuardianProver, guardianProvers } from '$stores';
	import Filter from './Filter.svelte';
	import { refreshData } from '$lib/dataFetcher';
	import { goto } from '$app/navigation';
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';

	let loading = false;
	let filtered = false;
	let isDesktopOrLarger: boolean;

	let filteredGuardianProvers = [];

	const manualRefresh = async () => {
		await refreshData();
	};

	const openDetails = (guardianProver: Guardian) => {
		$selectedGuardianProver = guardianProver;
		goto(guardianProver.id.toString());
	};

	onMount(async () => {
		if (!$guardianProvers) await manualRefresh();
	});

	$: dataToDisplay = filtered
		? filteredGuardianProvers
		: $guardianProvers === null
			? []
			: $guardianProvers;
</script>

<div class="mt-[12px]">
	<Filter bind:filteredGuardianProvers refreshData={manualRefresh} bind:loading bind:filtered />

	<GuardianProverTableHeader />
	<div class="space-y-[8px]">
		{#each dataToDisplay as guardianProver (guardianProver.id)}
			<GuardianProverTableRow
				{guardianProver}
				on:click={() => openDetails(guardianProver)}
				on:keydown={() => openDetails(guardianProver)}
			/>
		{/each}
	</div>
	<!-- {/if} -->
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
