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
	import { Icon } from '$components/Icon';

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

<div class="f-row w-full text-md md:text-[1.5rem]">
	{#if $selectedGuardianProver}
		<a href="/" class="" on:click={() => ($selectedGuardianProver = null)}>
			<span class="text-left font-bold text-tertiary-content">{$t('headings.overview')}</span>
		</a>

		<div class="pl-[10px] pr-[5px]">
			<Icon type="chevron-right" size={23} class="mt-[5px]" />
		</div>
		<span class="font-bold">{$t('common.prover')} {$selectedGuardianProver.id}</span>
	{:else}
		<span class="text-left font-bold">{$t('headings.overview')}</span>
	{/if}
</div>

<div class="mt-[12px]">
	{#if loading}
		<Filter bind:filteredGuardianProvers {refreshData} bind:loading bind:filtered />

		<div class="flex justify-center items-center w-full h-full my-[30px]">
			<Spinner />
			<span class="ml-5">{$t('loading')}</span>
		</div>
	{:else if !$selectedGuardianProver}
		<Filter bind:filteredGuardianProvers {refreshData} bind:loading bind:filtered />

		<OverviewTableHeader />
		<div class="space-y-[8px]">
			{#each dataToDisplay as guardianProver (guardianProver.id)}
				<OverviewTableRow
					{guardianProver}
					on:click={() => openDetails(guardianProver)}
					on:keydown={() => openDetails(guardianProver)}
				/>
			{/each}
		</div>
	{:else if $selectedGuardianProver}
		<HealthChecksList />
	{/if}
</div>
