<script lang="ts">
  import Blocks from "./Blocks.svelte";
  import GuardianProvers from "./GuardianProvers.svelte";

  let activeTab: string = "guardianprovers";
</script>

<div class="tabs">
  <a
    class="tab {activeTab === 'guardianprovers' ? 'tab-active' : ''} "
    on:click={() => (activeTab = "guardianprovers")}>Guardian Provers</a
  >
  <a
    class="tab {activeTab === 'blocks' ? 'tab-active' : ''} "
    on:click={() => (activeTab = "blocks")}
  >
    Blocks
  </a>
</div>

<div>
  {#if activeTab === "blocks"}
    <Blocks />
  {:else}
    <GuardianProvers />
  {/if}
</div>
