<script lang="ts">
  import { onDestroy, onMount } from "svelte";
  import {
    fetchSignedBlocks,
    type SignedBlock,
    type SignedBlocks,
  } from "../utils/fetchGuardianProverStats";
  import BlockDetailsModal from "./BlockDetailsModal.svelte";

  let loading: boolean = false;
  let blocks: SignedBlocks = {};
  let interval: NodeJS.Timeout;
  let blockDetailsModalOpen: boolean = false;

  let activeBlock: SignedBlock[] = [];
  let activeKey: string = "";

  onMount(async () => {
    loading = true;
    blocks = await fetchSignedBlocks(
      import.meta.env.VITE_GUARDIAN_PROVER_API_URL
    );

    setInterval(async () => {
      blocks = await fetchSignedBlocks(
        import.meta.env.VITE_GUARDIAN_PROVER_API_URL
      );
    }, 30 * 1000);
  });

  function setActiveBlock(key: string, block: SignedBlock[]) {
    activeBlock = block;
    activeKey = key;
  }

  onDestroy(() => {
    clearInterval(interval);
  });
</script>

<h2 class="text-xl">Last 100 Blocks</h2>
<div class="overflow-x-auto">
  <!-- head -->
  {#each Object.entries(blocks) as [key, block]}
    <details class="collapse bg-base-200">
      <summary class="collapse-title text-xl font-medium">
        <div on:click={() => setActiveBlock(key, block)}>
          Block ID: {key}
        </div></summary
      >

      <div class="collapse-content">
        {#each block as b}
          <p>Guardian ProverID: {b.guardianProverID}</p>
          <p>Signed Block Hash: {b.blockHash}</p>
          <p>Signature: {b.signature}</p>
        {/each}
      </div>
    </details>
  {/each}
</div>
