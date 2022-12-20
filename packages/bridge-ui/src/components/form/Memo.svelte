<script lang="ts">
  import TooltipModal from "../modals/TooltipModal.svelte";
  import Tooltip from "../Tooltip.svelte";

  export let memo: string = "";
  let showMemo: boolean = true;
  let tooltipOpen: boolean = false;

  function onChange(e: any) {
    showMemo = e.target.checked;
  }
</script>

<div class="form-control mb-2">
  <label class="label cursor-pointer">
    <span class="label-text"
      >Memo
      <span class="inline-block" on:click={() => (tooltipOpen = true)}>
        <Tooltip />
      </span></span
    >
    <input
      type="checkbox"
      class="toggle rounded-full"
      on:change={onChange}
      bind:checked={showMemo}
    />
  </label>

  {#if showMemo}
    <input
      type="text"
      placeholder="Memo..."
      class="input input-primary bg-dark-4 input-md md:input-lg w-full"
      name="memo"
      bind:value={memo}
    />
  {/if}
</div>

<TooltipModal title="Memo" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <p>
      You can attach an arbitrary message to your bridge transaction <br />
      by using a memo. It will slightly increase gas costs.
    </p>
  </span>
</TooltipModal>
