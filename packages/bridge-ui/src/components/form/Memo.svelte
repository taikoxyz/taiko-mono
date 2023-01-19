<script lang="ts">
  import TooltipModal from "../modals/TooltipModal.svelte";
  import Tooltip from "../Tooltip.svelte";
  import ButtonWithTooltip from "../ButtonWithTooltip.svelte";

  export let memo: string = "";
  let showMemo: boolean = false;
  let tooltipOpen: boolean = false;
  export let memoError: string;

  function checkSizeLimit(input) {
    const bytes = (new TextEncoder().encode(input)).length;
    if(bytes > 128) {
      memoError = 'Max limit reached'
    } else {
      memoError = null;
    }
  }

  $: checkSizeLimit(memo);
</script>

<div class="flex flex-row justify-between mb-2">
  <ButtonWithTooltip onClick={() => (tooltipOpen = true)}>
    <span slot="buttonText">Memo</span>
  </ButtonWithTooltip>
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
<div class="form-control">
  <input
    type="text"
    placeholder="Enter memo here..."
    class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2 rounded-md mb-2"
    name="memo"
    bind:value={memo}
  />
  <label class="label min-h-[20px] mb-0 p-0" for="name">
    <span class="label-text-alt text-error text-sm">{memoError ?? ''}</span>
  </label>
</div>
{/if}

<TooltipModal title="Memo" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <p class="text-left">
      You can attach an arbitrary message to your bridge transaction by using a
      memo — it will slightly increase gas costs.
    </p>
  </span>
</TooltipModal>
