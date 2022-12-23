<script lang="ts">
  import TooltipModal from "../modals/TooltipModal.svelte";
  import Tooltip from "../Tooltip.svelte";

  export let memo: string = "";
  let showMemo: boolean = false;
  let tooltipOpen: boolean = false;
</script>

<div class="flex flex-row justify-between mb-2">
  <span class="label-text">
    Memo
    <span
      class="inline-block cursor-pointer"
      on:click={() => (tooltipOpen = true)}
    >
      <Tooltip />
    </span>
  </span>
  <input
    type="checkbox"
    class="toggle rounded-full duration-300"
    on:click={() => {
      showMemo = !showMemo;
    }}
    bind:checked={showMemo}
  />
</div>

{#if showMemo}
  <input
    type="text"
    placeholder="Enter memo here..."
    class="input input-primary bg-dark-4 input-md md:input-lg w-full mb-2"
    name="memo"
    bind:value={memo}
  />
{/if}

<TooltipModal title="Memo" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <p class="text-left">
      You can attach an arbitrary message to your bridge transaction by using a
      memo — it will slightly increase gas costs.
    </p>
  </span>
</TooltipModal>
