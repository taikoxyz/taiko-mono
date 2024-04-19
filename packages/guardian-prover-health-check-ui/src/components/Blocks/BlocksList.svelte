<script lang="ts">
	import Paginator from '$components/Paginator/Paginator.svelte';
	import { signedBlocks, totalGuardianProvers, guardianProvers } from '$stores';
	import { Spinner } from '$components/Spinner';
	import { t } from 'svelte-i18n';

	const pageSize = 10;
	let currentPage = 0;

	$: totalItems = $signedBlocks.length;

	const handlePageChange = async (selectedPage: number) => {
		currentPage = selectedPage;
	};

	$: blocksToDisplay = $signedBlocks.slice(currentPage * pageSize, (currentPage + 1) * pageSize);
</script>

<h1 class="text-left">{$t('headings.blocks')}</h1>

<div class="my-[45px]"><!-- spacer --></div>
<div class="flex flex-col space-y-2">
	<div class="grid grid-cols-5 items-center font-bold pl-3 pe-12">
		<div>{$t('blocks.id')}</div>
		<div class="col-span-3">{$t('blocks.signed')}</div>
	</div>
	{#each blocksToDisplay as { blockNumber, blocks }, index (blockNumber)}
		{@const singedByProvers = blocks.sort((a, b) => a.guardianProverID - b.guardianProverID)}
		{@const missingProverIDs = Array.from(
			{ length: $totalGuardianProvers },
			(_, i) => i + 1
		).filter((id) => !singedByProvers.find((p) => p.guardianProverID === id))}
		{@const missingProvers = missingProverIDs.map((id) => ({
			guardianProverID: id,
			blockHash: 'N/A',
			signature: 'N/A'
		}))}
		{@const allProvers = [...singedByProvers, ...missingProvers]}
		{@const displayProvers = allProvers.sort((a, b) => a.guardianProverID - b.guardianProverID)}
		<div class="collapse collapse-arrow bg-base-200 rounded-lg shadow-md">
			<input type="checkbox" id={`block-${index}`} class="peer" />
			<label for={`block-${index}`} class="collapse-title font-medium items-center">
				<div class="grid grid-cols-5 items-center">
					<div class="font-bold">{blockNumber}</div>
					{#if $totalGuardianProvers}
						<div class="col-span-3">{blocks.length}/{$totalGuardianProvers}</div>
					{:else}
						<div class="col-span-3">{blocks.length}/<Spinner class="w-2 h-2" /></div>
					{/if}
				</div>
			</label>
			<div class="collapse-content bg-white">
				{#each displayProvers as p}
					{@const guardianProver = $guardianProvers?.find(
						(g) => Number(g.id) === Number(p.guardianProverID)
					)}
					<div class="grid grid-cols-4 items-center border-b py-[24px]">
						<div class="f-col">
							<p class="font-bold">{guardianProver?.name}</p>
						</div>

						<div class="space-y-[10px] text-sm w-full col-span-3">
							<div>
								<p class="text-secondary-content">{$t('common.address')}</p>
								<span class="break-100-chars">
									{guardianProver?.address}
								</span>
							</div>

							<div>
								<p class="text-secondary-content">{$t('blocks.signed_hash')}</p>
								<span class="break-100-chars">{p.blockHash}</span>
							</div>
							<div>
								<p class="text-secondary-content">{$t('blocks.signature')}</p>
								<span class="break-100-chars">{p.signature}</span>
							</div>
						</div>
					</div>
				{/each}
			</div>
		</div>
	{/each}
</div>

<Paginator
	{pageSize}
	bind:totalItems
	on:pageChange={({ detail: selectedPage }) => handlePageChange(selectedPage)}
/>

<style>
	.break-100-chars {
		width: 500px;
		word-wrap: break-word;
	}
</style>
