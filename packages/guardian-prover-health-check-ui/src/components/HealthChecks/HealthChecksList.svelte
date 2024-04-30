<script lang="ts">
	import type { HealthCheck } from '$lib/types';
	import { onMount } from 'svelte';
	import HealthCheckRow from './HealthCheckRow.svelte';
	import { t } from 'svelte-i18n';
	import Paginator from '$components/Paginator/Paginator.svelte';
	import { page } from '$app/stores';
	import { Spinner } from '$components/Spinner';

	import HealthCheckFilter from './HealthCheckFilter.svelte';
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import { fetchGuardianProverHealthChecksFromApi } from '$lib/api';

	let isDesktopOrLarger: boolean;
	let healthChecks: HealthCheck[] = [];
	let nextHealthCheckPage: number = 0;
	let pageSize: number = 10;
	let totalItems: number = 0;

	let filteredHealthChecks = healthChecks;

	export let selectedGuardianProver = null;

	const startFetching = async () => {
		await fetchHealthChecks();

		const healthCheckInterval = setInterval(() => {
			fetchHealthChecks();
		}, 1200);

		return () => {
			clearInterval(healthCheckInterval);
		};
	};

	const fetchHealthChecks = async () => {
		const data = await fetchGuardianProverHealthChecksFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			nextHealthCheckPage,
			pageSize,
			selectedGuardianProver?.id
		);
		healthChecks = data.items;
		totalItems = data.total;
	};

	onMount(async () => {
		if (!selectedGuardianProver) {
			selectedGuardianProver = $page.url.pathname.slice($page.url.pathname.lastIndexOf('/') + 1);
		}
		await startFetching();
	});

	const handlePageChange = async (selectedPage: number) => {
		const data = await fetchGuardianProverHealthChecksFromApi(
			import.meta.env.VITE_GUARDIAN_PROVER_API_URL,
			selectedPage,
			pageSize,
			selectedGuardianProver?.id
		);
		healthChecks = data.items;
	};
</script>

<div class="mt-[12px] mb-[45px]">
	<HealthCheckFilter {healthChecks} bind:filteredHealthChecks />
</div>
{#if filteredHealthChecks.length === 0}
	<div class="flex gap-2">
		<Spinner />{$t('loading')}
	</div>
{:else if isDesktopOrLarger}
	<div class="grid grid-cols-12 overflow-y-scroll">
		<div class="col-span-1 font-bold text-content-primary border-b border-gray-300">
			{$t('overview.detail.table.status')}
		</div>
		<div class="col-span-5 font-bold text-content-primary border-b border-gray-300">
			{$t('overview.detail.table.expected_address')}
		</div>
		<div class="col-span-4 font-bold text-content-primary border-b border-gray-300">
			{$t('overview.detail.table.actual_address')}
		</div>
		<div class="col-span-2 font-bold text-content-primary border-b border-gray-300">
			{$t('overview.detail.table.created_on')}
		</div>
		{#each filteredHealthChecks as healthCheck}
			<HealthCheckRow {healthCheck} />
		{/each}
	</div>
{:else}
	<div class="grid grid-cols-12 overflow-y-scroll">
		<div class="col-span-12 font-bold text-content-primary border-b border-gray-300">
			{$t('overview.detail.table.healthchecks')}
		</div>
		{#each filteredHealthChecks as healthCheck}
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
