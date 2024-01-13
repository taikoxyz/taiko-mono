<script lang="ts">
	import { onMount } from 'svelte';
	import type { Guardian } from '$lib/types';
	import Spinner from '$components/Spinner/Spinner.svelte';
	import { GuardianProverTableHeader, GuardianProverTableRow } from '../GuardianProver/';
	import { selectedGuardianProver } from '$components/stores/guardianProver';
	import { t } from 'svelte-i18n';
	import Filter from './Filter.svelte';
	import { guardianProvers, manualFetch } from '$lib/dataFetcher';
	import { goto } from '$app/navigation';
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';

	let loading = false;
	let filtered = false;
	let isDesktopOrLarger: boolean;

	let filteredGuardianProvers = [];

	const refreshData = async () => {
		loading = true;
		await manualFetch();
		loading = false;
	};

	const openDetails = (guardianProver: Guardian) => {
		$selectedGuardianProver = guardianProver;
		goto(guardianProver.id.toString());
	};

	onMount(async () => {
		if (!$guardianProvers) await refreshData();
	});

	$: dataToDisplay = filtered
		? filteredGuardianProvers
		: $guardianProvers === null
			? []
			: $guardianProvers;
</script>

<div class="mt-[12px]">
	{#if loading}
		<Filter bind:filteredGuardianProvers {refreshData} bind:loading bind:filtered />
		<div class="flex justify-center items-center w-full h-full my-[30px]">
			<Spinner />
			<span class="ml-5">{$t('loading')}</span>
		</div>
	{:else}
		<Filter bind:filteredGuardianProvers {refreshData} bind:loading bind:filtered />

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
	{/if}
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
