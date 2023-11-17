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

  let activeBlock: SignedBlock[];
  let activeKey: string = "";

  onMount(async () => {
    loading = true;
    blocks = await fetchSignedBlocks(
      import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS
    );

    setInterval(async () => {
      blocks = await fetchSignedBlocks(
        import.meta.env.VITE_GUARDIAN_PROVER_CONTRACT_ADDRESS
      );
    }, 30 * 1000);
  });

  function openBlockDetailsModal(key: string, block: SignedBlock[]) {
    activeBlock = block;
    activeKey = key;
    blockDetailsModalOpen = true;
  }

  onDestroy(() => {
    clearInterval(interval);
  });
</script>

<h2 class="text-xl">Blocks</h2>
<div class="overflow-x-auto">
  <table class="table">
    <!-- head -->
    <thead>
      <tr>
        <th>BlockID</th>
      </tr>
    </thead>
    <tbody>
      {#each Object.entries(blocks) as [key, block]}
        <tr on:click={() => openBlockDetailsModal(key, block)}>
          <th>{key}</th>
        </tr>
      {/each}
    </tbody>
  </table>
</div>

{#if blockDetailsModalOpen}
  <BlockDetailsModal
    title={`Block ID ${activeKey}`}
    bind:isOpen={blockDetailsModalOpen}
  >
    <div
      class="grid grid-cols-3 gap-4 text-center my-10 max-h-96 overflow-x-auto overflow-y-auto"
      slot="body"
    >
      {#each activeBlock as block}
        <p>Guardian ProverID: {block.guardianProverID}</p>
        <p>Signed Block Hash: {block.blockHash}</p>
        <p>Signature: {block.signature}</p>
      {/each}
    </div>
  </BlockDetailsModal>
{/if}
