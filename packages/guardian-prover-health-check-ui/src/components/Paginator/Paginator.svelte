<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { t } from 'svelte-i18n';
	import { Icon } from '$components/Icon';

	export let currentPage = 1;
	export let totalItems = 0;
	export let pageSize = 5;

	$: totalPages = Math.ceil(totalItems / pageSize);

	const dispatch = createEventDispatcher<{ pageChange: number }>();

	function goToPage(page: number) {
		currentPage = page;
		dispatch('pageChange', page);
	}

	function handleKeydown(event: KeyboardEvent) {
		if (event.key === 'Enter') {
			goToPage(currentPage);
		}
	}

	const btnClass = 'btn btn-xs btn-ghost';
</script>

<div class="pagination btn-group pt-4">
	{#if currentPage !== 1}
		<button class={btnClass} on:click={() => goToPage(currentPage - 1)}>
			<Icon type="chevron-left" /></button
		>
	{/if}
	{$t('paginator.page')}
	<input
		type="number"
		class="form-control mx-1 text-center rounded-md py-1 px-8"
		bind:value={currentPage}
		min={1}
		max={totalPages}
		on:keydown={handleKeydown}
		on:blur={() => goToPage(currentPage)}
	/>
	{$t('paginator.of')}
	{totalPages}
	<button
		class={btnClass + (currentPage === totalPages ? ' invisible' : '')}
		on:click={() => goToPage(currentPage + 1)}><Icon type="chevron-right" /></button
	>
</div>

<style>
	.pagination {
		justify-content: flex-end;
		align-items: flex-end;
		gap: 10px;
		display: flex;
		align-items: center;
	}
	.invisible {
		opacity: 0;
		pointer-events: none;
	}
</style>
