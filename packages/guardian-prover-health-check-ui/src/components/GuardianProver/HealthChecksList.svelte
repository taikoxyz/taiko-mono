<script lang="ts">
	import { selectedGuardianProver } from '$components/stores/guardianProver';
	import { fetchGuardianProverRequests } from '$lib/guardianProver/fetchGuardianProverStats';

	import type { HealthCheck } from '$lib/types';
	import { onMount } from 'svelte';
	import HealthCheckRow from './HealthCheckRow.svelte';
	import { t } from 'svelte-i18n';
	import Paginator from '$components/Paginator/Paginator.svelte';

	import HealthCheckFilter from './HealthCheckFilter.svelte';
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';

	let isDesktopOrLarger: boolean;
	let healthChecks: HealthCheck[] = [];
	let nextHealthCheckPage: number = 0;
	let pageSize: number = 10;
	let totalItems: number = 0;

	let filteredHealthChecks = healthChecks;

	// check if at least 80% of the health checks are true
	let ok =
		healthChecks.filter((healthCheck) => healthCheck.alive).length >= healthChecks.length * 0.8;

	onMount(async () => {
		const page = await fetchGuardianProverRequests(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			nextHealthCheckPage,
			pageSize,
			$selectedGuardianProver.id
		);
		healthChecks = page.items;
		totalItems = page.total;
	});

	const handlePageChange = async (selectedPage: number) => {
		const page = await fetchGuardianProverRequests(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			selectedPage,
			pageSize,
			$selectedGuardianProver.id
		);
		healthChecks = page.items;
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
