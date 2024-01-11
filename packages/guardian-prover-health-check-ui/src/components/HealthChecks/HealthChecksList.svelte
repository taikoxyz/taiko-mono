<script lang="ts">
	// import { selectedGuardianProver } from '$components/stores/guardianProver';

	import type { HealthCheck } from '$lib/types';
	import { onMount } from 'svelte';
	import HealthCheckRow from './HealthCheckRow.svelte';
	import { t } from 'svelte-i18n';
	import Paginator from '$components/Paginator/Paginator.svelte';
	import { page } from '$app/stores';

	import HealthCheckFilter from './HealthCheckFilter.svelte';
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import { fetchGuardianProverHealthChecksFromApi } from '$lib/api';
	import { goto } from '$app/navigation';
	import { manualFetch } from '$lib/dataFetcher';

	let isDesktopOrLarger: boolean;
	let healthChecks: HealthCheck[] = [];
	let nextHealthCheckPage: number = 0;
	let pageSize: number = 10;
	let totalItems: number = 0;

	let filteredHealthChecks = healthChecks;

	export let selectedGuardianProver = null;

	onMount(async () => {
		if (!selectedGuardianProver) {
			// slice id from $page.url.pathname.lastIndexOf('/')
			selectedGuardianProver = $page.url.pathname.slice($page.url.pathname.lastIndexOf('/') + 1);
		}
		const data = await fetchGuardianProverHealthChecksFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			nextHealthCheckPage,
			pageSize,
			selectedGuardianProver.id
		);
		healthChecks = data.items;
		totalItems = data.total;
	});

	const handlePageChange = async (selectedPage: number) => {
		const data = await fetchGuardianProverHealthChecksFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			selectedPage,
			pageSize,
			selectedGuardianProver.id
		);
		healthChecks = data.items;
	};
</script>

<div class="mt-[12px] mb-[45px]">
	<HealthCheckFilter {healthChecks} bind:filteredHealthChecks />
</div>
{#if isDesktopOrLarger}
	<div class="grid grid-cols-12">
		<div class="col-span-1 font-bold text-content-primary border-b border-gray-300 mb-[10px]">
			{$t('overview.detail.table.status')}
		</div>
		<!-- <div class="col-span-1 font-bold text-content-primary border-b border-gray-300">
		{$t('overview.detail.table.uptime')}
	</div> -->
		<div class="col-span-5 font-bold text-content-primary border-b border-gray-300 mb-[10px]">
			{$t('overview.detail.table.expected_address')}
		</div>
		<div class="col-span-4 font-bold text-content-primary border-b border-gray-300 mb-[10px]">
			{$t('overview.detail.table.actual_address')}
		</div>
		<div class="col-span-2 font-bold text-content-primary border-b border-gray-300 mb-[10px]">
			{$t('overview.detail.table.created_on')}
		</div>
		{#each filteredHealthChecks as healthCheck, index (healthCheck.id)}
			<HealthCheckRow {healthCheck} />
		{/each}
	</div>
{:else}
	<div class="grid grid-cols-12">
		{#each filteredHealthChecks as healthCheck, index (healthCheck.id)}
			<HealthCheckRow {healthCheck} />
		{/each}
	</div>
{/if}
<Paginator
	{pageSize}
	bind:totalItems
	on:pageChange={({ detail: selectedPage }) => handlePageChange(selectedPage)}
/>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
