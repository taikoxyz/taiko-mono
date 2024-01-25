<script lang="ts">
	import type { Guardian } from '$lib/types';
	import { onMount } from 'svelte';
	import { GuardianProverStatus } from '$lib/types';
	import StatusFilterDropdown from './StatusFilterDropdown.svelte';
	import { RotatingIcon } from '$components/Icon';
	import { guardianProvers } from '$stores';
	import DesktopOrLarger from '$components/DesktopOrLarger/DesktopOrLarger.svelte';
	import { classNames } from '$lib/util/classNames';

	import { loading as loadingStore } from '$stores';

	export let refreshData: () => void;
	export let filteredGuardianProvers: Guardian[] = [];
	export let loading: boolean = false;
	export let filtered: boolean = false;

	let isDesktopOrLarger: boolean;

	const filterByStatus = (status: GuardianProverStatus) => {
		selectedStatus = status;

		filteredGuardianProvers = $guardianProvers?.filter((guardianProver) => {
			return Number(guardianProver.alive) === Number(status);
		});
	};

	const reset = () => {
		selectedStatus = null;
		filteredGuardianProvers = $guardianProvers;
		filtered = false;
	};

	$: selectedStatus = null;

	$: spin = loading || $loadingStore;

	$: if (selectedStatus !== null) {
		filtered = true;
		filterByStatus(selectedStatus);
	} else {
		reset();
	}

	$: classes = classNames('flex space-x-4', isDesktopOrLarger ? 'justify-end' : 'justify-between');

	onMount(() => {
		reset();
	});
</script>

<div class={classes}>
	<button class="btn btn-xs w-[36px] h-[36px] rounded-full" on:click={refreshData}
		><RotatingIcon type="refresh" bind:loading={spin} /></button
	>
	<StatusFilterDropdown bind:selectedStatus />
</div>

<DesktopOrLarger bind:is={isDesktopOrLarger} />
