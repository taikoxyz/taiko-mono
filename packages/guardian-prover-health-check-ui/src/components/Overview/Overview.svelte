<script lang="ts">
	import { fetchGuardianProversFromContract } from '$lib/guardianProver/fetchGuardianProversFromContract';
	import { onDestroy, onMount } from 'svelte';
	import OverviewTableRow from './OverviewTableRow.svelte';
	import type { Guardian } from '$lib/types';
	import Spinner from '$components/Spinner/Spinner.svelte';
	import OverviewTableHeader from './OverviewTableHeader.svelte';
	import { selectedGuardianProver } from '$components/stores/guardianProver';
	import HealthChecksList from '$components/GuardianProver/HealthChecksList.svelte';
	import { t } from 'svelte-i18n';
	import Filter from './Filter.svelte';
	import { fetchGuardians, guardianProvers } from '$lib/dataFetcher';

	let loading = false;
	let filtered = false;

	let filteredGuardianProvers = [];

	const refreshData = async () => {
		loading = true;
		await fetchGuardians();
		loading = false;
	};

	const openDetails = (guardianProver: Guardian) => {
		$selectedGuardianProver = guardianProver;
	};

	onMount(async () => {
		await refreshData();
	});

	onDestroy(() => {
		$selectedGuardianProver = null;
	});

	$: dataToDisplay = filtered ? filteredGuardianProvers : $guardianProvers;
</script>

<h1 class="text-left">{$t('headings.overview')}</h1>

{#if loading}
	<Filter bind:filteredGuardianProvers {refreshData} bind:loading bind:filtered />

	<div class="flex justify-center items-center w-full h-full">
		<Spinner />
		<span class="ml-5">{$t('loading')}</span>
	</div>
{:else if !$selectedGuardianProver}
	<Filter bind:filteredGuardianProvers {refreshData} bind:loading bind:filtered />

	<OverviewTableHeader />
	<div class="space-y-[8px]">
		{#each dataToDisplay as guardianProver (guardianProver.id)}
			<OverviewTableRow {guardianProver} on:click={() => openDetails(guardianProver)} />
		{/each}
	</div>
{:else if $selectedGuardianProver}
	<HealthChecksList />
{/if}
