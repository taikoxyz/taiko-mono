<script lang="ts">
	import type { Guardian } from '$lib/types';
	import { onMount } from 'svelte';
	import { GuardianProverStatus } from '$lib/types';
	import StatusFilterDropdown from './StatusFilterDropdown.svelte';
	import { RotatingIcon } from '$components/Icon';
	import { guardianProvers } from '$lib/dataFetcher';

	export let refreshData: () => void;
	export let filteredGuardianProvers: Guardian[] = [];
	export let loading: boolean = false;
	export let filtered: boolean = false;

	const filterByStatus = (status: GuardianProverStatus) => {
		selectedStatus = status;

		filteredGuardianProvers = $guardianProvers.filter((guardianProver) => {
			return Number(guardianProver.alive) === Number(status);
		});
	};

	const reset = () => {
		selectedStatus = null;
		filteredGuardianProvers = $guardianProvers;
		filtered = false;
	};

	$: selectedStatus = null;

	$: if (selectedStatus !== null) {
		filtered = true;
		filterByStatus(selectedStatus);
	} else {
		reset();
	}

	onMount(() => {
		reset();
	});
</script>

<div class="flex justify-end space-x-4">
	<button class="btn btn-xs w-[36px] h-[36px] rounded-full" on:click={refreshData}
		><RotatingIcon type="refresh" bind:loading /></button
	>
	<StatusFilterDropdown bind:selectedStatus />
</div>
