<script lang="ts">
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import TooltipModal from '../TooltipModal.svelte';

  export let memo: string = '';
  export let error: string = '';
  export let show: boolean = false;

  let tooltipOpen: boolean = false;

  function checkSizeLimit(input: string) {
    const bytes = new TextEncoder().encode(input).length;
    if (bytes > 128) {
      error = 'Max limit reached';
    } else {
      error = null;
    }
  }

  $: checkSizeLimit(memo);
</script>

<div class="label flex flex-row justify-between items-center">
  <label for="memo">
    <ButtonWithTooltip onClick={() => (tooltipOpen = true)}>
      <span slot="buttonText">Memo</span>
    </ButtonWithTooltip>
  </label>

  <input
    id="memo"
    type="checkbox"
    class="toggle rounded-full duration-300"
    on:click={() => {
      show = !show;
    }}
    bind:checked={show} />
</div>

{#if show}
  <div class="form-control">
    <input
      type="text"
      placeholder="Enter memo here…"
      class="input input-primary bg-dark-2 input-md md:input-lg w-full focus:ring-0 border-dark-2 rounded-md"
      name="memo"
      bind:value={memo} />

    {#if error}
      <label class="label min-h-[20px] mb-0 p-0" for="name">
        <span class="label-text-alt text-error text-sm">⚠ {error}</span>
      </label>
    {/if}
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
