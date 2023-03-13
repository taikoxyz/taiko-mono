<script lang="ts">
  import ButtonWithTooltip from '../ButtonWithTooltip.svelte';
  import TooltipModal from '../modals/TooltipModal.svelte';

  export let showTo: boolean = false;
  export let to: string = '';

  let tooltipOpen: boolean = false;
</script>

<div class="flex flex-row justify-between mb-2">
  <ButtonWithTooltip onClick={() => (tooltipOpen = true)}>
    <span slot="buttonText">Memo</span>
  </ButtonWithTooltip>

  <input
    type="checkbox"
    class="toggle rounded-full duration-300"
    on:click={() => {
      showTo = !showTo;
    }}
    bind:checked={showTo} />
</div>
{#if showTo}
  <input
    type="text"
    class="input input-primary"
    placeholder="0x..."
    name="to"
    bind:value={to} />
{/if}

<TooltipModal title="Custom Recipient" bind:isOpen={tooltipOpen}>
  <span slot="body">
    <p class="text-left">
      You can set a custom address as the recipient of your funds, instead of
      your current wallet address.
    </p>
  </span>
</TooltipModal>
