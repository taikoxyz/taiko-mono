<script lang="ts">
	import { Overview } from '$components/Overview';
	import { BlocksList } from '$components/Blocks';
	import { selectedTab } from '$stores';
	import { PageTabs } from '$lib/types';
</script>

{#if $selectedTab === PageTabs.GUARDIAN_PROVER}
	<Overview />
{:else if $selectedTab === PageTabs.BLOCKS}
	<BlocksList />
{/if}
